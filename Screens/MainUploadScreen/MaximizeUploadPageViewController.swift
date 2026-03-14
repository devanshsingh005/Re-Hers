//
//  MaximizeUploadPageViewController.swift
//  Re-Hearse_v1
//

import UIKit
import PDFKit

final class MaximizeUploadPageViewController: UIViewController {

    var pdfDocument: PDFDocument?

    private let pdfView   = PDFView()
    private let closeBtn  = UIButton(type: .system)
    private let zoomInBtn = UIButton(type: .system)
    private let zoomOutBtn = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // PDF
        pdfView.document         = pdfDocument
        pdfView.autoScales       = true
        pdfView.displayMode      = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor  = .black
        pdfView.minScaleFactor   = 0.1
        pdfView.maxScaleFactor   = 8.0
        pdfView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(pdfView)

        // Button bar (back | zoom out | zoom in) — bottom center
        let bar = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        bar.layer.cornerRadius = 22
        bar.clipsToBounds = true
        bar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bar)

        [closeBtn, zoomOutBtn, zoomInBtn].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.tintColor = .white
            bar.contentView.addSubview($0)
        }

        closeBtn.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        zoomOutBtn.setImage(UIImage(systemName: "minus.magnifyingglass"), for: .normal)
        zoomInBtn.setImage(UIImage(systemName: "plus.magnifyingglass"), for: .normal)

        [closeBtn, zoomOutBtn, zoomInBtn].forEach {
            $0.imageView?.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        }

        closeBtn.addTarget(self,   action: #selector(close),    for: .touchUpInside)
        zoomInBtn.addTarget(self,  action: #selector(zoomIn),   for: .touchUpInside)
        zoomOutBtn.addTarget(self, action: #selector(zoomOut),  for: .touchUpInside)

        // Dividers
        let div1 = divider()
        let div2 = divider()
        bar.contentView.addSubview(div1)
        bar.contentView.addSubview(div2)

        NSLayoutConstraint.activate([
            // PDF fills screen
            pdfView.topAnchor.constraint(equalTo: view.topAnchor),
            pdfView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pdfView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pdfView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // Bar — bottom center
            bar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            bar.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bar.heightAnchor.constraint(equalToConstant: 52),

            // Close (back)
            closeBtn.leadingAnchor.constraint(equalTo: bar.contentView.leadingAnchor, constant: 4),
            closeBtn.centerYAnchor.constraint(equalTo: bar.contentView.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 56),
            closeBtn.heightAnchor.constraint(equalTo: bar.heightAnchor),

            div1.leadingAnchor.constraint(equalTo: closeBtn.trailingAnchor),
            div1.centerYAnchor.constraint(equalTo: bar.contentView.centerYAnchor),
            div1.widthAnchor.constraint(equalToConstant: 1),
            div1.heightAnchor.constraint(equalToConstant: 28),

            // Zoom out
            zoomOutBtn.leadingAnchor.constraint(equalTo: div1.trailingAnchor, constant: 4),
            zoomOutBtn.centerYAnchor.constraint(equalTo: bar.contentView.centerYAnchor),
            zoomOutBtn.widthAnchor.constraint(equalToConstant: 56),
            zoomOutBtn.heightAnchor.constraint(equalTo: bar.heightAnchor),

            div2.leadingAnchor.constraint(equalTo: zoomOutBtn.trailingAnchor),
            div2.centerYAnchor.constraint(equalTo: bar.contentView.centerYAnchor),
            div2.widthAnchor.constraint(equalToConstant: 1),
            div2.heightAnchor.constraint(equalToConstant: 28),

            // Zoom in
            zoomInBtn.leadingAnchor.constraint(equalTo: div2.trailingAnchor, constant: 4),
            zoomInBtn.centerYAnchor.constraint(equalTo: bar.contentView.centerYAnchor),
            zoomInBtn.widthAnchor.constraint(equalToConstant: 56),
            zoomInBtn.heightAnchor.constraint(equalTo: bar.heightAnchor),
            zoomInBtn.trailingAnchor.constraint(equalTo: bar.contentView.trailingAnchor, constant: -4),
        ])

        if let first = pdfView.document?.page(at: 0) { pdfView.go(to: first) }
    }

    // MARK: - Actions
    @objc private func close() { dismiss(animated: true) }

    @objc private func zoomIn() {
        let next = min(pdfView.scaleFactor * 1.4, pdfView.maxScaleFactor)
        UIView.animate(withDuration: 0.2) { self.pdfView.scaleFactor = next }
    }

    @objc private func zoomOut() {
        let next = max(pdfView.scaleFactor / 1.4, pdfView.minScaleFactor)
        UIView.animate(withDuration: 0.2) { self.pdfView.scaleFactor = next }
    }

    // MARK: - Helper
    private func divider() -> UIView {
        let v = UIView()
        v.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }
}
