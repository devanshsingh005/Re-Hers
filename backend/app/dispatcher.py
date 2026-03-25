"""Worker function for processing jobs from the Redis queue."""
import asyncio
import logging
import tempfile
import os
import json
from uuid import uuid4
from app.audiveris_client import run_audiveris
from app.label_notes import process as run_label_notes
try:
    import fitz  # PyMuPDF
except ImportError:
    fitz = None
from app.database import DatabaseClient
from app.storage import StorageManager
from app.config import SUPABASE_URL, SUPABASE_KEY

# basicConfig is a no-op when worker.py has already configured the root logger,
# so add the FileHandler explicitly so job logs always reach dispatcher.log.
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
)
_root_logger = logging.getLogger()
_log_path = os.path.join(os.getenv("LOG_DIR", "/tmp"), "dispatcher.log")
if not any(
    isinstance(h, logging.FileHandler)
    and getattr(h, 'baseFilename', '').endswith('dispatcher.log')
    for h in _root_logger.handlers
):
    _fh = logging.FileHandler(_log_path)
    _fh.setFormatter(logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s'))
    _root_logger.addHandler(_fh)
logger = logging.getLogger(__name__)

# Clients initialised once per worker process at import time
db_client = DatabaseClient(SUPABASE_URL, SUPABASE_KEY)
storage_manager = StorageManager(SUPABASE_URL, SUPABASE_KEY, db_client)

# Terminal statuses checked in the duplicate guard.
# 'completed' alone is not enough — see guard logic below for details.
_DONE_STATUSES = {"completed", "completed_with_warning", "failed"}


def _log_safe_error(exc: Exception) -> str:
    return type(exc).__name__


# ---------------------------------------------------------------------------
# PDF normalisation helper
# ---------------------------------------------------------------------------

def normalize_pdf_ctm(pdf_path: str) -> str:
    """
    Wrap each page's existing content stream in a q/Q graphics-state save/restore
    pair so that any page-level CTM set by the original content (e.g. the
    0.06-scale transform Audiveris/MuseScore PDFs use internally) is fully
    enclosed before PyMuPDF appends new text via insert_text.

    Without this, insert_text inherits the existing CTM and places labels at
    ~0.06x the intended position (upper-left corner).

    Returns the path to the normalised PDF (a new temp file if changes were
    needed, otherwise the original path).
    """
    if fitz is None:
        return pdf_path  # PyMuPDF unavailable — label_notes will handle it
    try:
        doc = fitz.open(pdf_path)
        needs_wrap = False
        for page in doc:
            raw = page.read_contents()
            # Detect an unbalanced leading CTM: present when the content stream
            # starts by setting a non-identity transform matrix ("... cm") at the
            # top level (i.e. before the first q/Q save pair).
            # Heuristic: the first "cm" operator appears before the first "q".
            text = raw.decode("latin-1", errors="replace")
            first_q  = text.find(" q")
            first_cm = text.find(" cm")
            if first_cm != -1 and (first_q == -1 or first_cm < first_q):
                needs_wrap = True
                break
        if needs_wrap:
            for page in doc:
                page.wrap_contents()
            tmp = tempfile.NamedTemporaryFile(suffix=".pdf", delete=False)
            tmp.close()
            doc.save(tmp.name, garbage=4, deflate=True)
            doc.close()
            logger.info(f"normalize_pdf_ctm: wrapped page content in q/Q -> {tmp.name}")
            return tmp.name
        doc.close()
        logger.debug("normalize_pdf_ctm: no unbalanced CTM detected, using original PDF")
        return pdf_path
    except Exception as e:
        logger.warning(f"normalize_pdf_ctm failed (using original PDF): {e}")
        return pdf_path


# ---------------------------------------------------------------------------
# JSON layout normalisation helper
# ---------------------------------------------------------------------------

def normalize_json_for_pdf(json_data: dict, pdf_path: str) -> dict:
    """
    Auto-correct JSON page-layout parameters to match actual PDF geometry.
    Pure math — zero hardcoded values, zero observational bias.

    Two structural issues that Audiveris can produce in certain PDFs:

    1. page-width / page-height in the JSON do not match the actual PDF.
       Fix: recompute from (actual_pdf_dimension / tenths_to_pt), derived
       entirely from the JSON's own <scaling> block and the real PDF size.

    2. system-margins/left-margin encodes absolute position from the page
       edge instead of being relative to page-margins/left-margin.
       Detection (pure geometry, no bias): after applying Fix 1, if treating
       the margin as relative would place the system's right edge BEYOND the
       actual page width (physical impossibility), the encoding must be
       absolute. Fix: zero page-margins/left-margin so label_notes uses
       only the system margin, which already carries the absolute position.

    Only applied to native-size PDFs (no CropBox). For scanned/cropped
    PDFs the existing t2pt_x = actual_width / xml_page_width calibration
    in label_notes.py is already correct.
    """
    import copy
    if fitz is None:
        return json_data

    try:
        doc = fitz.open(pdf_path)
        page = doc[0]
        actual_width  = page.rect.width
        actual_height = page.rect.height
        mb = page.mediabox
        cb = page.cropbox
        doc.close()

        # Non-cropped PDFs: cropbox == mediabox (within 1 pt)
        has_crop = (
            abs(mb.x0 - cb.x0) > 1 or abs(mb.y0 - cb.y0) > 1 or
            abs(mb.x1 - cb.x1) > 1 or abs(mb.y1 - cb.y1) > 1
        )
        if has_crop:
            logger.debug("normalize_json_for_pdf: CropBox detected, skipping JSON correction")
            return json_data

        json_data = copy.deepcopy(json_data)
        score    = json_data["score-partwise"]
        defaults = score["defaults"]
        scaling  = defaults["scaling"]

        # tenths → PDF points factor, derived purely from JSON <scaling> block
        tenths_to_pt = (
            float(scaling["millimeters"]) / float(scaling["tenths"]) * 2.83465
        )

        pl = defaults["page-layout"]

        # Fix 1: correct page dimensions — the only valid definition is:
        #   page_width_pt = page_width_tenths * tenths_to_pt
        # Rearranged: page_width_tenths = actual_width / tenths_to_pt
        orig_pw = float(pl["page-width"])
        orig_ph = float(pl["page-height"])
        correct_pw = actual_width  / tenths_to_pt
        correct_ph = actual_height / tenths_to_pt
        pl["page-width"]  = str(round(correct_pw, 4))
        pl["page-height"] = str(round(correct_ph, 4))
        logger.info(
            f"normalize_json_for_pdf: page-width {orig_pw:.1f} -> {correct_pw:.1f} tenths  "
            f"page-height {orig_ph:.1f} -> {correct_ph:.1f} tenths  "
            f"(actual={actual_width:.1f}x{actual_height:.1f} pt, "
            f"tenths_to_pt={tenths_to_pt:.5f})"
        )

        # Fix 2: detect absolute system-margin encoding via pure geometry.
        #
        # After Fix 1, tenths_to_pt is the uniform scale for ALL coordinates.
        # In valid MusicXML, the system's right edge must fit within the page:
        #   (page_lm + sys_lm + sum_of_all_measure_widths_in_system) * tenths_to_pt
        #   <= actual_width
        #
        # If this inequality is violated, the system physically overflows the
        # page — geometrically impossible — meaning page_lm is being
        # double-counted (Audiveris encoded sys_lm as absolute, not relative).
        # Fix: zero page-margins/left-margin so label_notes only applies sys_lm.
        pm = pl["page-margins"]
        pm_dict = pm[0] if isinstance(pm, list) else pm
        page_lm = float(pm_dict.get("left-margin", 0))

        if page_lm > 0:
            part     = score["part"]
            if isinstance(part, list): part = part[0]
            measures = part.get("measure", [])
            if isinstance(measures, dict): measures = [measures]

            # Find the first system's left-margin
            sys_lm = None
            for m in measures[:10]:
                pe = m.get("print", {})
                if not pe:
                    continue
                sl  = pe.get("system-layout", {})
                sm  = sl.get("system-margins", {})
                lm  = sm.get("left-margin")
                if lm is not None:
                    sys_lm = float(lm)
                    break

            if sys_lm is not None:
                # Sum all measure widths in the first system
                sys1_width_tenths = 0.0
                for i, m in enumerate(measures):
                    pe = m.get("print", {}) if m.get("print") else {}
                    if i > 0:
                        new_sys = str(pe.get("@new-system", "")).lower() == "yes"
                        new_pg  = str(pe.get("@new-page",   "")).lower() == "yes"
                        if new_sys or new_pg:
                            break
                    w = m.get("@width")
                    if w:
                        sys1_width_tenths += float(w)

                # Geometric overflow check — pure math, no thresholds
                system_right_if_relative = (
                    (page_lm + sys_lm + sys1_width_tenths) * tenths_to_pt
                )
                if system_right_if_relative > actual_width:
                    pm_dict["left-margin"]  = "0"
                    pm_dict["right-margin"] = "0"
                    logger.info(
                        f"normalize_json_for_pdf: relative-margin encoding would place "
                        f"system right edge at {system_right_if_relative:.1f} pt "
                        f"> page width {actual_width:.1f} pt — "
                        f"page margins zeroed (sys_lm={sys_lm} is absolute)"
                    )
                else:
                    logger.debug(
                        f"normalize_json_for_pdf: relative-margin encoding fits page "
                        f"({system_right_if_relative:.1f} pt <= {actual_width:.1f} pt) "
                        f"— page margins kept"
                    )

        return json_data

    except Exception as e:
        logger.warning(f"normalize_json_for_pdf failed (using original JSON): {e}")
        return json_data


# ---------------------------------------------------------------------------
# Public RQ entry point
# ---------------------------------------------------------------------------

def process_job(job_data: dict) -> None:
    """RQ worker entry point. Wraps the entire async pipeline in one event loop.

    Args:
        job_data: {"job_id": str}
    """
    asyncio.run(async_process_job(job_data))


# ---------------------------------------------------------------------------
# Core async pipeline
# ---------------------------------------------------------------------------

async def async_process_job(job_data: dict) -> None:
    """Process a single job end-to-end.

    Pipeline:
        1. Recover any jobs stuck in 'processing' from previous worker crashes
        2. Duplicate guard — skip if job is already in a terminal status
        3. Download input PDF from Supabase Storage
        4. Call Audiveris API → get JSON
        5. Save JSON to storage
        6. Run label_notes → create labeled PDF
        7. Save labeled PDF to storage
        8. Update job status

    Args:
        job_data: {"job_id": str}
    """
    job_id = job_data["job_id"]
    logger.info(f"=== START processing job {job_id} ===")
    tmp_pdf_path = None
    tmp_json_path = None
    tmp_labeled_pdf_path = None

    try:
        logger.info(f"[1/7] Fetching job from database...")

        # --- Fetch job from database ---
        jobs_response = (
            db_client.client.table("jobs").select("*").eq("id", job_id).execute()
        )

        if not jobs_response.data:
            logger.error(f"Job {job_id} not found in database")
            return

        job = jobs_response.data[0]

        # --- Duplicate guard ---
        # NOTE: The iOS frontend may directly write status='completed' to Supabase
        # before the worker runs. A truly completed job will have label_status set.
        # If label_status is None, the job was never actually processed — proceed.
        if job["status"] in _DONE_STATUSES:
            if job.get("label_status") is not None or job["status"] == "failed":
                logger.info(f"Job {job_id} already '{job['status']}' (label_status={job.get('label_status')}) — skipping")
                return
            else:
                logger.warning(f"Job {job_id} has status='{job['status']}' but label_status=None — frontend set it early, processing anyway")

        user_id = job["user_id"]
        pdf_path = job["pdf_path"]

        # --- Mark as processing ---
        logger.info(f"[2/7] Marking job {job_id} as processing...")
        await db_client.update_job_status(job_id, user_id, "processing")
        logger.info("[2/7] Processing job %s for user %s", job_id, user_id)

        # =========================================================================
        # STEP 1: Download PDF from Supabase Storage
        # =========================================================================
        logger.info("[3/7] Downloading PDF for job %s", job_id)
        try:
            pdf_content = storage_manager.client.storage.from_("pdf_uploads").download(pdf_path)
            logger.info(f"[3/7] PDF downloaded: {len(pdf_content)} bytes")
        except Exception as e:
            logger.error("[3/7] FAILED to download PDF: %s", _log_safe_error(e))
            raise

        with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
            tmp.write(pdf_content)
            tmp_pdf_path = tmp.name

        # =========================================================================
        # STEP 2: Call Audiveris API → get JSON
        # =========================================================================
        logger.info(f"[4/7] Calling Audiveris API for job {job_id}...")
        logger.info("[4/7] Temporary PDF prepared for job %s", job_id)
        logger.info("[4/7] PDF file size: %s bytes", os.path.getsize(tmp_pdf_path) if os.path.exists(tmp_pdf_path) else "N/A")
        try:
            json_output = run_audiveris(tmp_pdf_path)
            logger.info(f"[4/7] Audiveris call succeeded! Output type: {type(json_output).__name__}")
            logger.info("[4/7] Audiveris output received")
        except Exception as e:
            logger.error("[4/7] FAILED to call Audiveris: %s", _log_safe_error(e))
            raise

        if isinstance(json_output, str):
            json_output = json.loads(json_output)

        # =========================================================================
        # STEP 3: Save JSON to storage
        # =========================================================================
        output_json_path = f"{user_id}/{job_id}/output.json"
        # Compact encoding: ~25% smaller than indent=2. Safe because /sheets/{job_id}
        # returns json.loads(stored_bytes) which FastAPI re-serializes — stored
        # indentation is irrelevant to any client.
        json_bytes = json.dumps(json_output).encode("utf-8")

        logger.info("[5/7] Uploading JSON (%s bytes) for job %s", len(json_bytes), job_id)
        try:
            upload_response = storage_manager.client.storage.from_("sheet_data").upload(
                output_json_path,
                json_bytes,
                file_options={"content-type": "application/json", "upsert": "true"},
            )
            logger.info(f"[5/7] JSON upload completed.")
        except Exception as e:
            logger.error("[5/7] FAILED to upload JSON: %s", _log_safe_error(e))
            raise

        json_file_id = str(uuid4())
        await db_client.create_sheet_file(
            file_id=json_file_id,
            user_id=user_id,
            job_id=job_id,
            storage_path=output_json_path,
            file_size_bytes=len(json_bytes),
            status="completed",
        )

        # =========================================================================
        # STEP 4: Run label_notes → create labeled PDF
        # =========================================================================
        # Normalise JSON geometry in-process — json_output is already in memory
        # from the Audiveris call. Eliminates one redundant storage round-trip
        # (download + decode + json.loads) that previously happened every job.
        logger.info(f"[6/7] Normalising JSON geometry for label_notes (in-process)...")
        json_data_for_label = normalize_json_for_pdf(json_output, tmp_pdf_path)

        with tempfile.NamedTemporaryFile(suffix=".json", delete=False, mode="wb") as tmp:
            tmp.write(json.dumps(json_data_for_label).encode("utf-8"))
            tmp_json_path = tmp.name

        with tempfile.NamedTemporaryFile(suffix=".pdf", delete=False) as tmp:
            tmp_labeled_pdf_path = tmp.name

        logger.info(f"[6/7] Normalising PDF coordinate system...")
        normalised_pdf_path = normalize_pdf_ctm(tmp_pdf_path)

        logger.info(f"[6/7] Calling label_notes...")
        label_success = run_label_notes(
            pdf_path=normalised_pdf_path,
            json_path=tmp_json_path,
            output_path=tmp_labeled_pdf_path,
            debug=False,
        )
        logger.info(f"[6/7] label_notes completed: label_success={label_success}")
        logger.info("[6/7] Checking labeled PDF for job %s", job_id)
        logger.info("[6/7] Labeled PDF exists: %s", os.path.exists(tmp_labeled_pdf_path))
        if os.path.exists(tmp_labeled_pdf_path):
            logger.info("[6/7] Labeled PDF size: %s bytes", os.path.getsize(tmp_labeled_pdf_path))

        # Clean up normalised temp file if a new one was created
        if normalised_pdf_path != tmp_pdf_path and os.path.exists(normalised_pdf_path):
            os.unlink(normalised_pdf_path)

        # =========================================================================
        # STEP 5: Save labeled PDF to storage (if labeling succeeded)
        # =========================================================================
        label_status = None
        label_warning = None
        labeled_pdf_url = None

        if label_success and os.path.exists(tmp_labeled_pdf_path):
            try:
                logger.info(f"Uploading labeled PDF for job {job_id}")

                with open(tmp_labeled_pdf_path, "rb") as f:
                    labeled_pdf_content = f.read()

                pdf_result = await storage_manager.upload_labeled_pdf(
                    user_id,
                    job_id,
                    labeled_pdf_content,
                )

                label_status = "success"
                labeled_pdf_url = pdf_result["storage_path"]
                logger.info("Labeled PDF saved for job %s", job_id)
                logger.info("Labeled PDF reference stored for job %s", job_id)

            except Exception as e:
                logger.warning("Failed to save labeled PDF for %s: %s", job_id, _log_safe_error(e))
                label_status = "failed"
                label_warning = "Note labeling failed"
        else:
            logger.warning(f"label_notes processing failed for job {job_id}")
            label_status = "failed"
            label_warning = "Note labeling pipeline failed"

        # =========================================================================
        # STEP 6: Update job status
        # =========================================================================
        final_status = "completed" if label_status == "success" else "completed_with_warning"
        # Use labeled PDF if available, otherwise fall back to JSON
        if labeled_pdf_url:
            result_url = labeled_pdf_url
        else:
            result_url = output_json_path

        logger.info("[7/7] Final result ready for job %s", job_id)
        await db_client.update_job_status(
            job_id,
            user_id,
            final_status,
            result_url=result_url,
            label_status=label_status,
            label_warning=label_warning,
        )

        logger.info(
            f"Job {job_id} finished: status={final_status}, label_status={label_status}"
        )

    except Exception as e:
        error_message = _log_safe_error(e)
        logger.error("EXCEPTION in process_job %s: %s", job_id, error_message)
        try:
            jobs_response = (
                db_client.client
                .table("jobs")
                .select("id, user_id")
                .eq("id", job_id)
                .execute()
            )
            if jobs_response.data:
                user_id = jobs_response.data[0]["user_id"]
                logger.error(f"Updating job {job_id} status to 'failed'")
                await db_client.update_job_status(
                    job_id,
                    user_id,
                    "failed",
                    error_message=error_message,
                )
                logger.error(f"Successfully marked job {job_id} as failed")
        except Exception as db_error:
            logger.error(f"Failed to write failed status for job {job_id}: {db_error}")

        logger.error("Job %s failed with error type: %s", job_id, _log_safe_error(e))

    finally:
        for tmp_path in [tmp_pdf_path, tmp_json_path, tmp_labeled_pdf_path]:
            if tmp_path and os.path.exists(tmp_path):
                try:
                    os.unlink(tmp_path)
                except Exception as e:
                    logger.warning("Failed to cleanup temp file for job %s: %s", job_id, _log_safe_error(e))
