"""
Label Notes: Deterministic Music Note Label Overlay Pipeline

Reads a sheet music PDF and Audiveris MusicXML JSON, reconstructs layout
geometry entirely from JSON values, then renders pitch labels (e.g. "A4",
"E5") below each note head and saves an annotated PDF.

Supports:
* Single-staff and grand staff (treble + bass) scores
* Multi-system and multi-page scores
* Accidentals (sharps, flats)
* Optional debug mode (note anchors, staff lines, measure boxes)

Dependencies:
    pip install pymupdf
"""

import json
import os
import logging
import re
from typing import Optional

try:
    import fitz  # PyMuPDF
except ImportError:
    raise ImportError(
        "PyMuPDF is not installed. "
        "Install it with: pip install pymupdf"
    )

logger = logging.getLogger(__name__)


def _sanitize_upstream(value: str, max_len: int = 200) -> str:
    return re.sub(r'[^\x20-\x7E]', '', str(value))[:max_len]

# ---------------------------------------------------------------------------
# Pitch helpers
# ---------------------------------------------------------------------------

# Diatonic step names in ascending order (index 0=C, 1=D, ... 6=B)
STEP_ORDER = ["C", "D", "E", "F", "G", "A", "B"]


def pitch_to_diatonic_index(step: str, octave: int) -> int:
    """
    Convert a pitch to an absolute diatonic index.
    Index = octave * 7 + step_position_in_octave
    C4=28, D4=29, E4=30, F4=31, G4=32, A4=33, B4=34, C5=35 …
    """
    return octave * 7 + STEP_ORDER.index(step)


def pitch_label(note: dict) -> str:
    """
    Build a human-readable label for a pitched note, e.g. "A4", "G#5", "Bb4".
    Returns empty string for rests or notes without pitch.
    """
    pitch = note.get("pitch")
    if pitch is None:
        return ""
    step   = pitch["step"]
    octave = str(pitch["octave"])
    alter  = pitch.get("alter")
    if alter is not None:
        try:
            alter_val = float(alter)
        except (ValueError, TypeError):
            alter_val = 0.0
        if alter_val >= 1.0:
            return step + "#" + octave
        elif alter_val <= -1.0:
            return step + "b" + octave
    return step + octave


# ---------------------------------------------------------------------------
# Coordinate conversion — derived entirely from JSON scaling block
# ---------------------------------------------------------------------------

def compute_tenths_to_pt(scaling: dict) -> float:
    """
    Compute tenths → PDF points conversion factor.

    MusicXML scaling block provides millimetres and tenths such that:
        <millimetres> mm == <tenths> tenths

    1 mm = 2.83465 PDF points (ISO 32000).
    """
    millimeters  = float(scaling["millimeters"])
    tenths       = float(scaling["tenths"])
    tenths_to_mm = millimeters / tenths
    tenths_to_pt = tenths_to_mm * 2.83465
    return tenths_to_pt


# ---------------------------------------------------------------------------
# Staff geometry — derived from tenths_to_pt and MusicXML spec
# ---------------------------------------------------------------------------

# One staff-space = distance between two adjacent staff lines = 10 tenths.
# (MusicXML spec definition — not a hardcoded pixel value.)
STAFF_SPACE_TENTHS = 10.0


def staff_space_pt(tenths_to_pt: float) -> float:
    """Return one staff-space in PDF points, derived from JSON scaling."""
    return STAFF_SPACE_TENTHS * tenths_to_pt


# ---------------------------------------------------------------------------
# Clef definitions
# ---------------------------------------------------------------------------

# For each clef type we record: (top_line_step, top_line_octave)
# — the pitch that sits on the top staff line.
#
# Treble (G clef, line 2): top line = F5
# Bass   (F clef, line 4): top line = A3
CLEF_TOP_LINE = {
    "G": ("F", 5),   # Treble clef — top line is F5
    "F": ("A", 3),   # Bass clef   — top line is A3
    "C": ("A", 4),   # Alto/tenor C clef (line 3) — top line is A4 (approx)
}

# Default clef when not specified in the JSON
DEFAULT_CLEF_SIGN = "G"


def note_head_y_for_clef(staff_top_y: float, pitch: dict,
                          space_pt: float, clef_sign: str) -> float:
    """
    Compute the Y coordinate of a note head in PDF space.

    The staff has 5 lines. The top line carries the pitch defined in
    CLEF_TOP_LINE for that clef. Each diatonic step down = 0.5 × space_pt.

    Args:
        staff_top_y  : PDF y of the *top* staff line.
        pitch        : note pitch dict from JSON (has 'step' and 'octave').
        space_pt     : one staff-space in PDF points.
        clef_sign    : 'G', 'F', or 'C'.

    Returns:
        PDF y coordinate of the note head centre.
    """
    top_step, top_octave = CLEF_TOP_LINE.get(clef_sign, CLEF_TOP_LINE["G"])
    top_index  = pitch_to_diatonic_index(top_step, top_octave)

    step       = pitch["step"]
    octave     = int(pitch["octave"])
    note_index = pitch_to_diatonic_index(step, octave)

    # Positive steps_below → note is lower on staff → larger y in PDF
    steps_below_top = top_index - note_index

    return staff_top_y + steps_below_top * (space_pt / 2.0)


# ---------------------------------------------------------------------------
# Clef and stave parsing helpers
# ---------------------------------------------------------------------------

def parse_clefs(attributes: dict) -> dict:
    """
    Parse the clef definitions from an attributes block.

    Returns a dict: {staff_number (int): clef_sign (str)}
    Staff number 1 = first staff (default), 2 = second (bass), etc.

    Handles both single clef (dict) and multiple clefs (list).
    """
    result = {}
    clef_raw = attributes.get("clef")
    if clef_raw is None:
        return result
    if isinstance(clef_raw, dict):
        clef_raw = [clef_raw]
    for c in clef_raw:
        # @number defaults to "1" if absent (single-staff scores)
        num  = int(c.get("@number", "1"))
        sign = c.get("sign", DEFAULT_CLEF_SIGN)
        result[num] = sign
    return result


def parse_staff_distance(print_elem: dict, tenths_to_pt: float) -> float | None:
    """
    Extract the staff-distance from a measure's 'print' element.

    staff-distance = distance between the bottom of staff N and the top
    of staff N+1 (in tenths, converted to PDF pts).

    Returns None if not present.
    """
    sl = print_elem.get("staff-layout")
    if sl is None:
        return None
    # staff-layout may be a list (multiple staves) or a single dict
    if isinstance(sl, list):
        sl = sl[0]
    sd = sl.get("staff-distance")
    if sd is None:
        return None
    return float(sd) * tenths_to_pt


def get_note_staff_number(note: dict) -> int:
    """
    Determine which staff a note belongs to.

    Uses the 'staff' element from MusicXML (standard Audiveris output).
    Falls back to voice-based heuristic if staff is not present.
    """
    staff_raw = note.get("staff")
    if staff_raw is not None:
        try:
            return int(staff_raw)
        except (ValueError, TypeError):
            pass

    voice_raw = note.get("voice")
    if voice_raw is not None:
        try:
            voice = int(voice_raw)
            return 1 if voice <= 4 else 2
        except (ValueError, TypeError):
            pass

    return 1


# ---------------------------------------------------------------------------
# System layout extraction
# ---------------------------------------------------------------------------

def extract_system_layout(print_elem: dict) -> dict:
    """
    Pull system-layout geometry from a measure's 'print' element.

    Returns a dict (all values are floats in tenths, or None if absent):
        left_margin, right_margin, top_system_distance, system_distance
    """
    result = {
        "left_margin":         None,
        "right_margin":        None,
        "top_system_distance": None,
        "system_distance":     None,
    }
    sys_layout = print_elem.get("system-layout", {})

    margins = sys_layout.get("system-margins", {})
    if "left-margin" in margins:
        result["left_margin"]  = float(margins["left-margin"])
    if "right-margin" in margins:
        result["right_margin"] = float(margins["right-margin"])

    if "top-system-distance" in sys_layout:
        result["top_system_distance"] = float(sys_layout["top-system-distance"])
    if "system-distance" in sys_layout:
        result["system_distance"]     = float(sys_layout["system-distance"])

    return result


# ---------------------------------------------------------------------------
# Debug drawing helpers
# ---------------------------------------------------------------------------

def _t(page: fitz.Page, x: float, y: float) -> fitz.Point:
    """
    Transform a point from MusicXML/visual coordinates to PDF insertion
    coordinates by applying the page's derotation matrix.
    """
    return fitz.Point(x, y) * page.derotation_matrix


def debug_note_anchor(page: fitz.Page, x: float, y: float,
                      radius: float) -> None:
    """Draw a small red circle at computed note-head position."""
    centre = _t(page, x, y)
    page.draw_circle(centre, radius, color=(1, 0, 0), width=0.5)


def debug_staff_top_line(page: fitz.Page, x0: float, x1: float,
                         y: float) -> None:
    """Draw a thin green line at the staff top-line y."""
    page.draw_line(_t(page, x0, y), _t(page, x1, y),
                   color=(0, 0.6, 0), width=0.5)


def debug_measure_rect(page: fitz.Page, x: float, y: float,
                       w: float, h: float) -> None:
    """Draw a thin grey rectangle enclosing a measure."""
    tl = _t(page, x,     y)
    br = _t(page, x + w, y + h)
    page.draw_rect(fitz.Rect(tl, br), color=(0.5, 0.5, 0.5), width=0.4)


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------

def process(pdf_path: str | None, json_path: str, output_path: str,
            debug: bool = False) -> bool:
    """
    Full pipeline: PDF + JSON → annotated output PDF.
    
    Args:
        pdf_path: Path to input PDF (None or "-" creates blank canvas)
        json_path: Path to Audiveris JSON output
        output_path: Path to save labeled PDF
        debug: If True, draw geometry guides
    
    Returns:
        True if successful, False otherwise
    """
    try:
        # ------------------------------------------------------------------
        # 1. Load JSON
        # ------------------------------------------------------------------
        logger.info(f"Loading JSON from {json_path}")
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)

        # Check if the expected key exists
        if "score-partwise" not in data:
            # Audiveris likely returned an error
            logger.warning(f"Audiveris JSON missing 'score-partwise' key. Available keys: {list(data.keys())}")
            if "detail" in data:
                logger.error("Audiveris error detail: %s", _sanitize_upstream(data.get('detail', '')))
            if "stderr" in data:
                logger.error("Audiveris stderr: %s", _sanitize_upstream(data.get('stderr', '')))
            if "stdout" in data:
                logger.error("Audiveris stdout: %s", _sanitize_upstream(data.get('stdout', '')))
            return False
        
        score          = data["score-partwise"]
        defaults       = score["defaults"]
        scaling        = defaults["scaling"]
        page_layout    = defaults["page-layout"]
        page_margins   = page_layout["page-margins"]

        # Handle page-margins as list (odd/even) or dict
        if isinstance(page_margins, list):
            page_margins = page_margins[0]

        # ------------------------------------------------------------------
        # 2. Derive ALL geometry from JSON — zero hardcoded layout values
        # ------------------------------------------------------------------
        tenths_to_pt      = compute_tenths_to_pt(scaling)

        xml_page_height_tenths = float(page_layout["page-height"])
        xml_page_width_tenths  = float(page_layout["page-width"])

        page_height_pt    = xml_page_height_tenths * tenths_to_pt
        page_width_pt     = xml_page_width_tenths  * tenths_to_pt
        top_margin_pt     = float(page_margins["top-margin"])  * tenths_to_pt
        left_margin_pt    = float(page_margins["left-margin"]) * tenths_to_pt

        # Separate X and Y scale factors (will be recalibrated from PDF)
        t2pt_x = tenths_to_pt   # for horizontal: margins, default-x, measure widths
        t2pt_y = tenths_to_pt   # for vertical: system distance, staff distance, pitch

        logger.info(f"JSON tenths_to_pt = {tenths_to_pt:.5f}")
        logger.info(f"XML page size     = {page_width_pt:.1f} × {page_height_pt:.1f} pt")

        # ------------------------------------------------------------------
        # 3. Open or create PDF
        # ------------------------------------------------------------------
        use_blank = (pdf_path is None or pdf_path == "-"
                     or not os.path.isfile(pdf_path))

        if use_blank:
            logger.info("No input PDF — creating blank canvas.")
            doc = fitz.open()
        else:
            logger.info(f"Opening '{pdf_path}'")
            doc = fitz.open(pdf_path)

            # --------------------------------------------------------------
            # 3a. CALIBRATE X from actual PDF page width.
            #     For Y, keep the original tenths_to_pt from the scaling
            #     block — it matches the actual staff line spacing in the
            #     PDF (verified via pixel scanning).
            #     Audiveris top-system-distance is measured from the page
            #     top, so we do NOT add page top-margin.
            # --------------------------------------------------------------
            actual_rect = doc[0].rect
            actual_width  = actual_rect.width
            actual_height = actual_rect.height

            t2pt_x = actual_width / xml_page_width_tenths
            # t2pt_y stays as the original tenths_to_pt (correct for content)

            logger.info(f"PDF page size      = {actual_width:.1f} × {actual_height:.1f} pt")
            logger.info(f"t2pt_x = {t2pt_x:.5f}   t2pt_y = {t2pt_y:.5f} (original)")

            # Recompute X margin with calibrated factor
            left_margin_pt = float(page_margins["left-margin"]) * t2pt_x
            page_height_pt = actual_height
            page_width_pt  = actual_width

        # ------------------------------------------------------------------
        # 3b. Recompute all derived geometry with calibrated factors
        # ------------------------------------------------------------------
        space_pt_y        = STAFF_SPACE_TENTHS * t2pt_y   # vertical staff space
        staff_height_pt   = 4.0 * space_pt_y              # 5 lines, 4 spaces
        fontsize          = space_pt_y * 1.3
        label_offset_pt   = space_pt_y * 2.5              # below note head
        debug_radius      = space_pt_y * 0.25
        notehead_cx       = space_pt_y * 0.8              # X shift: centre under notehead

        logger.info(f"staff_space_y = {space_pt_y:.3f} pt")
        logger.info(f"fontsize      = {fontsize:.2f} pt")

        # ------------------------------------------------------------------
        # 4. Normalise measures list
        # ------------------------------------------------------------------
        part_data = score["part"]
        
        # Handle both cases: part as dict with measures, or part as list
        if isinstance(part_data, list):
            # If part is a list, use first part (most common case)
            part = part_data[0] if part_data else {}
        else:
            # If part is a dict, use it directly
            part = part_data
        
        measures = part.get("measure", [])
        if isinstance(measures, dict):
            measures = [measures]

        # ------------------------------------------------------------------
        # 5. Track active clef per staff across score
        # ------------------------------------------------------------------
        active_clefs: dict[int, str] = {1: DEFAULT_CLEF_SIGN}

        current_staff_distance_pt: float | None = None

        # ------------------------------------------------------------------
        # 6. Layout cursors
        # ------------------------------------------------------------------
        current_page_idx  = -1
        system_top_y      = 0.0
        system_left_x     = 0.0
        measure_start_x   = 0.0

        # ------------------------------------------------------------------
        # 7. Iterate over measures
        # ------------------------------------------------------------------
        for m_idx, measure in enumerate(measures):
            m_number         = measure.get("@number", str(m_idx + 1))
            # Handle missing @width attribute - use average width or skip if not available
            measure_width = measure.get("@width")
            if measure_width:
                measure_width_pt = float(measure_width) * t2pt_x
            else:
                # Default measure width if not provided
                measure_width_pt = page_width_pt / 6  # Approximate: ~6 measures per page

            # ---- Update active clef definitions
            attrs = measure.get("attributes", {})
            if attrs:
                new_clefs = parse_clefs(attrs)
                active_clefs.update(new_clefs)

            # ---- Detect page/system break
            print_elem = measure.get("print", {})
            new_page   = str(print_elem.get("@new-page",   "")).lower() == "yes"
            new_system = str(print_elem.get("@new-system", "")).lower() == "yes"
            is_first   = (m_idx == 0)

            sys_info = extract_system_layout(print_elem) if print_elem else {}

            # ---- Parse new staff distance (but don't apply yet — need the
            #      previous value for the system-advance calculation)
            new_staff_distance_pt = None
            if print_elem:
                sd = parse_staff_distance(print_elem, t2pt_y)
                if sd is not None:
                    new_staff_distance_pt = sd

            if is_first or new_page:
                current_page_idx += 1

                if use_blank:
                    doc.new_page(width=page_width_pt, height=page_height_pt)
                elif current_page_idx >= len(doc):
                    logger.warning(f"PDF has only {len(doc)} page(s) but "
                                  f"measure {m_number} needs page {current_page_idx + 1}. "
                                  "Adding blank page.")
                    doc.new_page(width=page_width_pt, height=page_height_pt)

                tsd = sys_info.get("top_system_distance")
                system_top_y = (tsd * t2pt_y
                                if tsd is not None else top_margin_pt)

                lm = sys_info.get("left_margin")
                system_left_x  = left_margin_pt + (lm * t2pt_x if lm else 0.0)
                measure_start_x = 0.0

                # NOW apply the new staff distance for this system
                if new_staff_distance_pt is not None:
                    current_staff_distance_pt = new_staff_distance_pt

                logger.debug(f"Measure {m_number}: NEW PAGE → page {current_page_idx + 1} "
                           f"system_top_y={system_top_y:.1f}")

            elif new_system:
                sd_sys = sys_info.get("system_distance")
                if sd_sys is not None:
                    # Advance past previous system using PREVIOUS staff distance
                    n_staves = len(active_clefs)
                    if current_staff_distance_pt is not None and n_staves > 1:
                        system_top_y += (n_staves * staff_height_pt
                                         + (n_staves - 1) * current_staff_distance_pt
                                         + sd_sys * t2pt_y)
                    else:
                        system_top_y += staff_height_pt + sd_sys * t2pt_y
                else:
                    n_staves = len(active_clefs)
                    if current_staff_distance_pt is not None:
                        system_top_y += (n_staves * staff_height_pt
                                         + (n_staves - 1) * current_staff_distance_pt
                                         + 5.0 * space_pt_y)
                    else:
                        system_top_y += staff_height_pt + 5.0 * space_pt_y

                lm = sys_info.get("left_margin")
                system_left_x  = left_margin_pt + (lm * t2pt_x if lm else 0.0)
                measure_start_x = 0.0

                # NOW apply the new staff distance for this system
                if new_staff_distance_pt is not None:
                    current_staff_distance_pt = new_staff_distance_pt

                logger.debug(f"Measure {m_number}: NEW SYSTEM y={system_top_y:.1f}")
            else:
                logger.debug(f"Measure {m_number}: width={measure_width_pt:.1f}pt")

            # ---- Get fitz page
            page = doc[current_page_idx]

            # ---- Compute staff 2 top Y (grand staff)
            if current_staff_distance_pt is not None:
                staff2_top_y = system_top_y + staff_height_pt + current_staff_distance_pt
            else:
                staff2_top_y = None

            # ---- Debug visuals
            if debug:
                meas_x = system_left_x + measure_start_x
                debug_measure_rect(page, meas_x, system_top_y,
                                   measure_width_pt, staff_height_pt)
                debug_staff_top_line(page, meas_x, meas_x + measure_width_pt,
                                     system_top_y)
                if staff2_top_y is not None:
                    debug_measure_rect(page, meas_x, staff2_top_y,
                                       measure_width_pt, staff_height_pt)
                    debug_staff_top_line(page, meas_x, meas_x + measure_width_pt,
                                         staff2_top_y)

            # ---- Process notes: collect labels per staff, then resolve collisions
            notes_raw = measure.get("note", [])
            if isinstance(notes_raw, dict):
                notes_raw = [notes_raw]

            # Collect: {staff_num: [(note_x, base_label_y, note_y, label_text), ...]}
            staff_labels: dict[int, list] = {}
            notes_found = 0
            invalid_note_count = 0

            for note in notes_raw:
                if "rest" in note or "pitch" not in note:
                    continue

                notes_found += 1
                label = pitch_label(note)
                if not label:
                    continue

                pitch = note["pitch"]

                # ---- Staff assignment
                staff_num  = get_note_staff_number(note)
                clef_sign  = active_clefs.get(staff_num, DEFAULT_CLEF_SIGN)

                # ---- Staff top Y
                if staff_num == 2 and staff2_top_y is not None:
                    this_staff_top_y = staff2_top_y
                else:
                    this_staff_top_y = system_top_y

                # ---- Horizontal position
                try:
                    default_x_pt = float(note["@default-x"]) * t2pt_x
                except (ValueError, TypeError) as e:
                    logger.debug("Skipped malformed note metadata field: %s", type(e).__name__)
                    invalid_note_count += 1
                    continue
                note_x = system_left_x + measure_start_x + default_x_pt - notehead_cx

                # ---- Vertical position (note head — for debug anchor only)
                note_y = note_head_y_for_clef(
                    this_staff_top_y, pitch, space_pt_y, clef_sign)

                # ---- Base label Y: fixed line below bottom staff line
                staff_bottom_y = this_staff_top_y + staff_height_pt
                base_label_y = staff_bottom_y + label_offset_pt

                staff_labels.setdefault(staff_num, []).append(
                    (note_x, base_label_y, note_y, label))

                if debug:
                    debug_note_anchor(page, note_x, note_y, debug_radius)

            if invalid_note_count > 0:
                logger.warning("Skipped %d malformed note(s) during processing", invalid_note_count)

            # ---- Resolve collisions and render labels
            min_label_gap = fontsize * 2.2  # minimum X gap between labels
            line_height   = fontsize * 1.8  # Y step when bumping down (more space)
            measure_end_x = system_left_x + measure_start_x + measure_width_pt
            bar_clearance = fontsize * 3.0  # space before/after measure boundary

            for staff_num, entries in staff_labels.items():
                # Sort by X so we can check left-to-right collisions
                entries.sort(key=lambda e: e[0])

                # For each label, track its final Y; bump down if too close
                placed: list[tuple[float, float]] = []  # (x, final_y)

                for note_x, base_y, note_y, label in entries:
                    final_x = note_x
                    final_y = base_y

                    # ---- Check if label is too close to measure boundary (barline)
                    if measure_end_x - final_x < bar_clearance:
                        # Label would overlap with right barline, push left
                        final_x = measure_end_x - bar_clearance

                    # ---- Check against already-placed labels for collision
                    for px, py in placed:
                        if abs(final_x - px) < min_label_gap and abs(final_y - py) < line_height:
                            # Bump below the colliding label
                            final_y = py + line_height

                    placed.append((final_x, final_y))

                    page.insert_text(
                        _t(page, final_x, final_y),
                        label,
                        fontsize=fontsize,
                        color=(0.0, 0.0, 0.0),
                    )

            if debug and notes_found > 0:
                logger.debug(f"Measure {m_number}: {notes_found} notes, "
                           f"{sum(len(v) for v in staff_labels.values())} labels")

            # ---- Advance measure cursor
            measure_start_x += measure_width_pt

        # ------------------------------------------------------------------
        # 8. Save
        # ------------------------------------------------------------------
        doc.save(output_path, garbage=4, deflate=True)
        doc.close()
        logger.info(f"Successfully saved labeled PDF to '{output_path}'")
        return True
    
    except Exception as e:
        logger.error(f"Failed to process label_notes: {e}", exc_info=True)
        return False


