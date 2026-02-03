//
//  UploadScreen.swift
//  Re-Hearse_v1
//

import UIKit
import AVFoundation
import Photos
import Supabase
import PDFKit // Add PDFKit for PDF creation

class UploadScreen: UIViewController {
    
    private enum Constants {
        static let horizontalPadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 20
        static let elementSpacing: CGFloat = 12
        static let cornerRadius: CGFloat = 14
        static let buttonHeight: CGFloat = 52
        static let uploadContainerHeight: CGFloat = 300
        static let cardSize = CGSize(width: 140, height: 160)
        static let carouselHeight: CGFloat = 180
        static let metaCoverSize: CGFloat = 56
        static let metaCornerRadius: CGFloat = metaCoverSize / 2 // circular
        static let pdfPageSize = CGSize(width: 612, height: 792) // US Letter size
    }
    
    // MARK: - State / Data
    private var uploadTitle: String = "Untitled"
    private var uploadCoverImage: UIImage? = UIImage(systemName: "music.note")
    private var currentUploadData: Data? // Store uploaded file data
    private var currentFileName: String = ""
    private var currentFileType: String = ""
    private var selectedImages: [UIImage] = [] // Store multiple selected images
    private var isMultiImageSelection = false // Track if we're in multi-image mode
    
    // UI Element references
    private var metaTitleLbl: UILabel?
    private var metaCoverImgView: UIImageView?
    private var recentHStack: UIStackView?
    
    // Use shared Supabase client
    private var supabase: SupabaseClient {
        return SupabaseManager.shared.client
    }
    
    // Supabase storage base URL
    private let supabaseStorageBaseURL = "https://djqgmowfjxsnjdffdohw.supabase.co/storage/v1/object/public"
    
    // MARK: - UI Elements
    private let navBar = TopNavBar.make(title: "Upload")
    private let scrollView = UIScrollView()
    private let contentView = UIStackView()
    
    private let uploadContainer = UIView()
    private let uploadIcon = UIImageView()
    private let uploadLabel = UILabel()
    private let uploadButton = UIButton()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        navigationController?.navigationBar.isHidden = true
        
        setupNavBar()
        setupScrollView()
        addUploadMetaSection()
        setupUploadSection()
        addRecentUploadsSection()
        
        // Load real recent uploads from database
        loadRecentUploadsFromDB()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh recent uploads when view appears
        loadRecentUploadsFromDB()
    }
    
    // MARK: - Image Processing for Scanned PDF Look
    private func processImageForScanLook(_ image: UIImage) -> UIImage {
        // Convert to grayscale first
        guard let ciImage = CIImage(image: image) else { return image }
        
        // Apply filters to make it look like a scanned document
        let context = CIContext(options: nil)
        
        // 1. Convert to grayscale
        guard let grayscaleFilter = CIFilter(name: "CIColorControls") else { return image }
        grayscaleFilter.setValue(ciImage, forKey: kCIInputImageKey)
        grayscaleFilter.setValue(0.0, forKey: kCIInputSaturationKey) // Remove color
        grayscaleFilter.setValue(1.1, forKey: kCIInputContrastKey) // Increase contrast
        grayscaleFilter.setValue(0.1, forKey: kCIInputBrightnessKey) // Adjust brightness
        
        guard let grayscaleOutput = grayscaleFilter.outputImage else { return image }
        
        // 2. Apply threshold (black and white effect)
        guard let thresholdFilter = CIFilter(name: "CIColorThreshold") else {
            // Fallback to simpler approach if threshold filter not available
            if let cgImage = context.createCGImage(grayscaleOutput, from: grayscaleOutput.extent) {
                return UIImage(cgImage: cgImage)
            }
            return image
        }
        thresholdFilter.setValue(grayscaleOutput, forKey: kCIInputImageKey)
        thresholdFilter.setValue(0.5, forKey: "inputThreshold") // Adjust threshold level
        
        guard let thresholdOutput = thresholdFilter.outputImage else {
            if let cgImage = context.createCGImage(grayscaleOutput, from: grayscaleOutput.extent) {
                return UIImage(cgImage: cgImage)
            }
            return image
        }
        
        // 3. Apply noise reduction
        guard let noiseFilter = CIFilter(name: "CINoiseReduction") else {
            if let cgImage = context.createCGImage(thresholdOutput, from: thresholdOutput.extent) {
                return UIImage(cgImage: cgImage)
            }
            return image
        }
        noiseFilter.setValue(thresholdOutput, forKey: kCIInputImageKey)
        noiseFilter.setValue(0.02, forKey: "inputNoiseLevel")
        noiseFilter.setValue(0.40, forKey: "inputSharpness")
        
        // 4. Apply sharpen filter for crisp text
        guard let sharpenFilter = CIFilter(name: "CISharpenLuminance") else {
            if let cgImage = context.createCGImage(thresholdOutput, from: thresholdOutput.extent) {
                return UIImage(cgImage: cgImage)
            }
            return image
        }
        sharpenFilter.setValue(noiseFilter.outputImage ?? thresholdOutput, forKey: kCIInputImageKey)
        sharpenFilter.setValue(0.5, forKey: kCIInputSharpnessKey)
        
        guard let finalOutput = sharpenFilter.outputImage else {
            if let cgImage = context.createCGImage(thresholdOutput, from: thresholdOutput.extent) {
                return UIImage(cgImage: cgImage)
            }
            return image
        }
        
        // Render the final image
        if let cgImage = context.createCGImage(finalOutput, from: finalOutput.extent) {
            return UIImage(cgImage: cgImage)
        }
        
        return image
    }
    
    // Alternative method using CoreGraphics for more reliable grayscale+threshold
    private func convertToScannedLook(_ image: UIImage) -> UIImage {
        let originalSize = image.size
        let scale: CGFloat = 2.0 // Use higher resolution for better quality
        let newSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        
        // Draw the original image
        image.draw(in: CGRect(origin: .zero, size: newSize))
        
        // Get the image data
        guard let cgImage = context.makeImage() else { return image }
        
        // Create a grayscale color space
        guard let colorSpace = CGColorSpace(name: CGColorSpace.genericGrayGamma2_2) else { return image }
        
        // Create bitmap context
        let bitmapInfo = CGImageAlphaInfo.none.rawValue
        guard let grayContext = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return image }
        
        // Draw the image into the grayscale context
        grayContext.draw(cgImage, in: CGRect(origin: .zero, size: newSize))
        
        // Apply contrast and brightness adjustments manually
        if let grayImage = grayContext.makeImage() {
            // Convert back to UIImage
            return UIImage(cgImage: grayImage, scale: scale, orientation: .up)
        }
        
        return image
    }
    
    // Simple thresholding for black and white effect
    private func applySimpleThreshold(_ image: UIImage, threshold: CGFloat = 0.6) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bytesPerPixel = 1
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        guard let pixelData = context.data else { return nil }
        
        let thresholdValue = UInt8(threshold * 255)
        let buffer = pixelData.bindMemory(to: UInt8.self, capacity: width * height)
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = y * width + x
                let pixel = buffer[offset]
                // Simple threshold: black or white
                buffer[offset] = pixel > thresholdValue ? 255 : 0
            }
        }
        
        if let newCGImage = context.makeImage() {
            return UIImage(cgImage: newCGImage)
        }
        
        return nil
    }
    
    // MARK: - Image to PDF Conversion Methods with Scanning Effect
    
    private func convertImagesToPDF(images: [UIImage]) -> Data? {
        guard !images.isEmpty else { return nil }
        
        let pdfData = NSMutableData()
        let pdfBounds = CGRect(origin: .zero, size: Constants.pdfPageSize)
        
        // Create PDF context with better quality settings
        UIGraphicsBeginPDFContextToData(pdfData, pdfBounds, nil)
        let rendererFormat = UIGraphicsImageRendererFormat.default()
        rendererFormat.opaque = true
        rendererFormat.scale = 2.0 // Higher resolution
        
        for (index, image) in images.enumerated() {
            // Start a new page for each image
            UIGraphicsBeginPDFPageWithInfo(pdfBounds, nil)
            
            // Convert image to scanned look
            let processedImage: UIImage
            if let thresholdedImage = applySimpleThreshold(image, threshold: 0.6) {
                processedImage = thresholdedImage
            } else {
                // Fallback to processed image
                processedImage = processImageForScanLook(image)
            }
            
            // Calculate image size to fit within page while maintaining aspect ratio
            let imageSize = processedImage.size
            let pageSize = Constants.pdfPageSize
            
            // Calculate scaling factor to fit the page
            let widthRatio = pageSize.width / imageSize.width
            let heightRatio = pageSize.height / imageSize.height
            let scaleFactor = min(widthRatio, heightRatio, 1.0) // Don't scale up
            
            let scaledWidth = imageSize.width * scaleFactor
            let scaledHeight = imageSize.height * scaleFactor
            
            // Center the image on the page
            let xOffset = (pageSize.width - scaledWidth) / 2
            let yOffset = (pageSize.height - scaledHeight) / 2
            
            let imageRect = CGRect(x: xOffset, y: yOffset, width: scaledWidth, height: scaledHeight)
            
            // Draw the processed (scanned-looking) image
            processedImage.draw(in: imageRect)
            
            // Optional: Add subtle border like a scanned document
            let borderRect = imageRect.insetBy(dx: -1, dy: -1)
            let borderPath = UIBezierPath(rect: borderRect)
            borderPath.lineWidth = 0.5
            UIColor.lightGray.setStroke()
            borderPath.stroke()
            
            // Optional: Add page number (small and discreet)
            let pageNumberText = "\(index + 1)"
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: UIColor.gray
            ]
            
            let textSize = pageNumberText.size(withAttributes: textAttributes)
            let textRect = CGRect(
                x: (pageSize.width - textSize.width) / 2,
                y: 10,
                width: textSize.width,
                height: textSize.height
            )
            
            pageNumberText.draw(in: textRect, withAttributes: textAttributes)
        }
        
        UIGraphicsEndPDFContext()
        
        return pdfData as Data
    }
    
    private func createPDFFromImages() -> (Data, String, String)? {
        guard !selectedImages.isEmpty else { return nil }
        
        // Process all images for scanned look
        let processedImages = selectedImages.map { image -> UIImage in
            if let thresholdedImage = self.applySimpleThreshold(image, threshold: 0.6) {
                return thresholdedImage
            } else {
                return self.processImageForScanLook(image)
            }
        }
        
        // Convert processed images to PDF
        if let pdfData = convertImagesToPDF(images: processedImages) {
            let timestamp = Date().timeIntervalSince1970
            let fileName = "scanned_\(Int(timestamp)).pdf"
            let fileType = "application/pdf"
            
            return (pdfData, fileName, fileType)
        }
        
        return nil
    }
    
    private func processSelectedImagesAndUpload() {
        guard !selectedImages.isEmpty else {
            DispatchQueue.main.async {
                self.uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
                self.uploadLabel.text = "No images selected"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.uploadLabel.text = "Drag & drop or tap to upload"
                }
            }
            return
        }
        
        // Show converting state
        DispatchQueue.main.async {
            self.uploadIcon.image = UIImage(systemName: "arrow.clockwise")
            self.uploadLabel.text = "Processing \(self.selectedImages.count) image(s) for scanned PDF..."
        }
        
        // Create PDF from images with scanning effect
        guard let (pdfData, fileName, fileType) = createPDFFromImages() else {
            DispatchQueue.main.async {
                self.uploadIcon.image = UIImage(systemName: "exclamationmark.triangle")
                self.uploadLabel.text = "Failed to create scanned PDF"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
                    self.uploadLabel.text = "Drag & drop or tap to upload"
                }
            }
            return
        }
        
        // Update upload data
        currentUploadData = pdfData
        currentFileName = fileName
        currentFileType = fileType
        
        // Start upload process
        Task {
            do {
                print("Starting multi-image scanned PDF upload task...")
                try await saveUploadToDatabase(
                    imageData: pdfData,
                    fileName: currentFileName,
                    fileType: currentFileType
                )
                
                print("Multi-image scanned PDF upload completed successfully!")
                
                // Clear selected images
                self.selectedImages.removeAll()
                self.isMultiImageSelection = false
                
                // Refresh recent uploads
                await self.loadRecentUploadsFromDB()
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    // Show success
                    self.uploadIcon.image = UIImage(systemName: "checkmark.circle.fill")
                    self.uploadLabel.text = "Scanned PDF created and uploaded!"
                    
                    // Reset after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
                        self.uploadLabel.text = "Drag & drop or tap to upload"
                    }
                }
            } catch {
                print("Multi-image scanned PDF upload failed with error: \(error)")
                print("Error details: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    // Show error
                    self.uploadIcon.image = UIImage(systemName: "exclamationmark.triangle")
                    self.uploadLabel.text = "Upload failed"
                    
                    // Reset after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
                        self.uploadLabel.text = "Drag & drop or tap to upload"
                    }
                    
                    // Show error alert
                    let alert = UIAlertController(
                        title: "Upload Failed",
                        message: "Error: \(error.localizedDescription)\n\nPlease try again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    // MARK: - Database Methods
    
    private func loadRecentUploadsFromDB() {
        Task {
            do {
                let recentUploads = try await fetchRecentUploadsFromDatabase()
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    self.displayRecentUploads(recentUploads)
                }
            } catch {
                print("Error loading recent uploads: \(error)")
                // Fallback to sample data if needed
                DispatchQueue.main.async {
                    self.addRecentUploadCard(title: "Sample Upload", image: UIImage(named: "cl_1"))
                }
            }
        }
    }
    
    private func fetchRecentUploadsFromDatabase() async throws -> [Scan] {
        // First, let's test if we can get the current user ID
        guard let userIdString = await getCurrentUserId() else {
            print("No user ID found")
            return []
        }
        
        guard let userId = UUID(uuidString: userIdString) else {
            print("Invalid user ID format: \(userIdString)")
            return []
        }
        
        print("Fetching scans for user ID: \(userId)")
        
        do {
            let response: [Scan] = try await supabase
                .from("scans")
                .select()
                .eq("user_id", value: userId)
                .order("updated_at", ascending: false)
                .limit(5)
                .execute()
                .value
            
            print("Successfully fetched \(response.count) scans")
            
            // Remove duplicates by ID to prevent showing same data multiple times
            var uniqueScans: [Scan] = []
            var seenIDs: Set<Int64> = []
            
            for scan in response {
                if !seenIDs.contains(scan.id) {
                    seenIDs.insert(scan.id)
                    uniqueScans.append(scan)
                }
            }
            
            print("After removing duplicates: \(uniqueScans.count) unique scans")
            return uniqueScans
        } catch {
            print("Error fetching scans: \(error)")
            throw error
        }
    }
    
    private func getCurrentUserId() async -> String? {
        do {
            // Get current session from Supabase
            let session = try await supabase.auth.session
            return session.user.id.uuidString
        } catch {
            print("Error getting user session: \(error)")
            return nil
        }
    }
    
    private func getSupabaseAuthToken() async -> String? {
        do {
            let session = try await supabase.auth.session
            return session.accessToken
        } catch {
            print("Error getting auth token: \(error)")
            return nil
        }
    }
    
    private func displayRecentUploads(_ scans: [Scan]) {
        guard let hStack = recentHStack else { return }
        
        // Clear existing cards
        for view in hStack.arrangedSubviews {
            view.removeFromSuperview()
        }
        
        // Add cards from database
        for scan in scans {
            let title = extractTitle(from: scan.jsonData) ?? scan.originalFilename ?? "Untitled"
            // You might want to store thumbnail URLs in JSON or use a placeholder
            addRecentUploadCard(title: title, image: UIImage(named: "cl_1"))
        }
        
        // If no uploads, show empty state
        if scans.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "No recent uploads"
            emptyLabel.textColor = .secondaryLabel
            emptyLabel.textAlignment = .center
            hStack.addArrangedSubview(emptyLabel)
        }
    }
    
    private func extractTitle(from jsonData: AnyCodable?) -> String? {
        guard let jsonData = jsonData else { return nil }
        
        // Access the underlying value
        if let dict = jsonData.value as? [String: Any] {
            return dict["title"] as? String
        }
        return nil
    }
    
    private func saveUploadToDatabase(imageData: Data, fileName: String, fileType: String) async throws {
        print("Starting upload process...")
        
        // 1. Get user ID
        guard let userIdString = await getCurrentUserId(),
              let userId = UUID(uuidString: userIdString) else {
            throw NSError(domain: "UploadError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid user ID"])
        }
        
        print("User ID: \(userId)")
        
        // 2. Get Supabase auth token for the external API
        print("Getting Supabase auth token...")
        guard let authToken = await getSupabaseAuthToken() else {
            throw NSError(domain: "UploadError", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get auth token"])
        }
        
        print("Auth token obtained, calling external API...")
        
        // 3. Call external conversion API with the image
        let apiResponse: [String: Any] = try await callExternalConversionAPI(
            imageData: imageData,
            fileName: fileName,
            fileType: fileType,
            authToken: authToken
        )
        
        print("External API response received")
        
        // 4. Extract job_id and user_id from API response
        guard let apiJobIdString = apiResponse["job_id"] as? String,
              let apiJobId = UUID(uuidString: apiJobIdString),
              let apiUserIdString = apiResponse["user_id"] as? String,
              let apiUserId = UUID(uuidString: apiUserIdString) else {
            throw NSError(domain: "UploadError", code: 5, userInfo: [NSLocalizedDescriptionKey: "Missing job_id or user_id in API response"])
        }
        
        print("Job ID from API: \(apiJobId)")
        print("User ID from API: \(apiUserId)")
        
        // 5. Construct the result URL
        let resultURL = "\(supabaseStorageBaseURL)/sheet_data/\(apiUserIdString.lowercased())/\(apiJobIdString.lowercased())/output.json"
        print("Constructed result URL: \(resultURL)")
        
        // 6. Create PDF path (based on the actual job ID from API)
        let pdfPath = "uploads/\(apiUserIdString)/\(apiJobIdString)/\(fileName)"
        
        // 7. First, check if a job with this ID already exists
        let existingJobs: [Job] = try await supabase
            .from("jobs")
            .select()
            .eq("id", value: apiJobId)
            .execute()
            .value
        
        if existingJobs.isEmpty {
            // 8. Create a job record in the jobs table with the API's job ID
            print("Creating job record with API job ID: \(apiJobId)")
            
            let jobInsert = JobInsert(
                id: apiJobId,
                userId: apiUserId,
                pdfPath: pdfPath,
                resultUrl: resultURL,
                status: "completed"
            )
            
            do {
                let jobResponse: Job = try await supabase
                    .from("jobs")
                    .insert(jobInsert)
                    .select()
                    .single()
                    .execute()
                    .value
                
                print("Job record inserted successfully with ID: \(jobResponse.id)")
            } catch {
                print("Error inserting job record: \(error)")
                // Continue even if job insertion fails
            }
        } else {
            print("Job already exists with ID: \(apiJobId)")
            
            // Update existing job with result URL
            let jobUpdate = JobUpdate(
                resultUrl: resultURL,
                status: "completed",
                errorMessage: nil,
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            try await supabase
                .from("jobs")
                .update(jobUpdate)
                .eq("id", value: apiJobId)
                .execute()
            
            print("Updated existing job with result URL")
        }
        
        // 9. Check if a scan record already exists for this job
        let existingScans: [Scan] = try await supabase
            .from("scans")
            .select()
            .eq("user_id", value: userId)
            .like("json_data->>'job_id'", pattern: "%\(apiJobIdString)%")
            .execute()
            .value
        
        if existingScans.isEmpty {
            // 10. Create a scan record in the scans table
            print("Creating scan record...")
            
            // Create processing ID for scan
            let processingId = "proc_\(UUID().uuidString)"
            
            // Create JSON data for scan
            var jsonDict: [String: Any] = [
                "status": "completed",
                "filename": fileName,
                "uploaded_at": ISO8601DateFormatter().string(from: Date()),
                "title": uploadTitle,
                "result_url": resultURL,
                "job_id": apiJobIdString,
                "user_id": apiUserIdString,
                "pdf_path": pdfPath,
                "pdf_type": "scanned" // Mark as scanned PDF
            ]
            
            // Merge API response into JSON
            for (key, value) in apiResponse {
                jsonDict[key] = value
            }
            
            let scanInsert = ScanInsert(
                userId: userId,
                jsonData: AnyCodable(jsonDict),
                processingId: processingId,
                status: "completed",
                originalFilename: fileName,
                fileType: fileType,
                processedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            let scanResponse: Scan = try await supabase
                .from("scans")
                .insert(scanInsert)
                .select()
                .single()
                .execute()
                .value
            
            print("Scan record inserted successfully with ID: \(scanResponse.id)")
            
            // 11. Now we can navigate to next page immediately
            DispatchQueue.main.async {
                self.navigateToNextPage(with: scanResponse.id, resultURL: resultURL)
            }
        } else {
            print("Scan already exists for job ID: \(apiJobIdString)")
            // Update existing scan
            if let existingScan = existingScans.first {
                var jsonDict: [String: Any] = [
                    "status": "completed",
                    "filename": fileName,
                    "uploaded_at": ISO8601DateFormatter().string(from: Date()),
                    "title": uploadTitle,
                    "result_url": resultURL,
                    "job_id": apiJobIdString,
                    "user_id": apiUserIdString,
                    "pdf_path": pdfPath,
                    "pdf_type": "scanned" // Mark as scanned PDF
                ]
                
                // Merge API response into JSON
                for (key, value) in apiResponse {
                    jsonDict[key] = value
                }
                
                let scanUpdate = ScanUpdate(
                    jsonData: AnyCodable(jsonDict),
                    status: "completed",
                    processedAt: ISO8601DateFormatter().string(from: Date()),
                    updatedAt: ISO8601DateFormatter().string(from: Date())
                )
                
                try await supabase
                    .from("scans")
                    .update(scanUpdate)
                    .eq("id", value: existingScan.id as! PostgrestFilterValue)
                    .execute()
                
                print("Updated existing scan with ID: \(existingScan.id)")
                
                // Navigate with existing scan ID
                DispatchQueue.main.async {
                    self.navigateToNextPage(with: existingScan.id, resultURL: resultURL)
                }
            }
        }
    }
    
    // MARK: - External API Call
    private func callExternalConversionAPI(
        imageData: Data,
        fileName: String,
        fileType: String,
        authToken: String
    ) async throws -> [String: Any] {
        let url = URL(string: "https://maybe-working-production.up.railway.app/convert")!
        
        // Create boundary for multipart form
        let boundary = UUID().uuidString
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // 60 second timeout for file upload
        
        // Build multipart form data
        var body = Data()
        
        // Add file part
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(fileType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Close boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        print("Making API request to: \(url.absoluteString)")
        print("File size: \(imageData.count) bytes")
        print("File name: \(fileName)")
        print("File type: \(fileType)")
        
        // Make the API call
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "APIError", code: 0,
                         userInfo: [NSLocalizedDescriptionKey: "No response from server"])
        }
        
        print("API Response Status Code: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8) ?? "No response body"
            print("API Error Response: \(responseBody)")
            throw NSError(domain: "APIError", code: httpResponse.statusCode,
                         userInfo: [NSLocalizedDescriptionKey: "API request failed with status \(httpResponse.statusCode): \(responseBody)"])
        }
        
        // Parse JSON response
        do {
            let jsonObject = try JSONSerialization.jsonObject(with: data)
            
            if let dict = jsonObject as? [String: Any] {
                print("External API returned: \(dict)")
                return dict
            } else if let array = jsonObject as? [[String: Any]], let first = array.first {
                print("External API returned array: using first element")
                return first
            } else {
                // If response is not a dictionary or array of dictionaries, wrap it
                return ["api_response": jsonObject, "status": "success"]
            }
        } catch {
            // If JSON parsing fails, return raw response as string
            let responseString = String(data: data, encoding: .utf8) ?? "No response body"
            print("External API raw response: \(responseString)")
            return ["raw_response": responseString, "status": "processed"]
        }
    }
    
    // MARK: - Data Models
    
    // Job table models
    struct Job: Codable, Identifiable {
        let id: UUID
        let userId: UUID
        let pdfPath: String
        let resultUrl: String?
        let status: String
        let errorMessage: String?
        let createdAt: String?
        let updatedAt: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case pdfPath = "pdf_path"
            case resultUrl = "result_url"
            case status
            case errorMessage = "error_message"
            case createdAt = "created_at"
            case updatedAt = "updated_at"
        }
    }
    
    struct JobInsert: Encodable {
        let id: UUID
        let userId: UUID
        let pdfPath: String
        let resultUrl: String?
        let status: String
        
        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case pdfPath = "pdf_path"
            case resultUrl = "result_url"
            case status
        }
    }
    
    struct JobUpdate: Encodable {
        let resultUrl: String?
        let status: String?
        let errorMessage: String?
        let updatedAt: String
        
        enum CodingKeys: String, CodingKey {
            case resultUrl = "result_url"
            case status
            case errorMessage = "error_message"
            case updatedAt = "updated_at"
        }
        
        // Add initializer with default values
        init(resultUrl: String? = nil, status: String? = nil, errorMessage: String? = nil, updatedAt: String) {
            self.resultUrl = resultUrl
            self.status = status
            self.errorMessage = errorMessage
            self.updatedAt = updatedAt
        }
    }
    
    // Scan table models
    struct Scan: Codable, Identifiable {
        let id: Int64
        let userId: UUID
        let jsonData: AnyCodable?
        let processingId: String?
        let status: String?
        let originalFilename: String?
        let fileType: String?
        let processedAt: String?
        let updatedAt: String?
        let errorMessage: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case userId = "user_id"
            case jsonData = "json_data"
            case processingId = "processing_id"
            case status
            case originalFilename = "original_filename"
            case fileType = "file_type"
            case processedAt = "processed_at"
            case updatedAt = "updated_at"
            case errorMessage = "error_message"
        }
    }
    
    struct ScanInsert: Encodable {
        let userId: UUID
        let jsonData: AnyCodable
        let processingId: String
        let status: String
        let originalFilename: String?
        let fileType: String?
        let processedAt: String?
        
        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case jsonData = "json_data"
            case processingId = "processing_id"
            case status
            case originalFilename = "original_filename"
            case fileType = "file_type"
            case processedAt = "processed_at"
        }
    }
    
    struct ScanUpdate: Encodable {
        let jsonData: AnyCodable
        let status: String
        let processedAt: String
        let updatedAt: String
        
        enum CodingKeys: String, CodingKey {
            case jsonData = "json_data"
            case status
            case processedAt = "processed_at"
            case updatedAt = "updated_at"
        }
    }
    
    // MARK: - AnyCodable helper for handling dynamic JSON
    struct AnyCodable: Codable {
        let value: Any
        
        init(_ value: Any) {
            self.value = value
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            
            if let boolValue = try? container.decode(Bool.self) {
                value = boolValue
            } else if let intValue = try? container.decode(Int.self) {
                value = intValue
            } else if let doubleValue = try? container.decode(Double.self) {
                value = doubleValue
            } else if let stringValue = try? container.decode(String.self) {
                value = stringValue
            } else if let arrayValue = try? container.decode([AnyCodable].self) {
                value = arrayValue.map { $0.value }
            } else if let dictValue = try? container.decode([String: AnyCodable].self) {
                value = dictValue.mapValues { $0.value }
            } else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable cannot decode value")
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            
            switch value {
            case let boolValue as Bool:
                try container.encode(boolValue)
            case let intValue as Int:
                try container.encode(intValue)
            case let doubleValue as Double:
                try container.encode(doubleValue)
            case let stringValue as String:
                try container.encode(stringValue)
            case let arrayValue as [Any]:
                let anyCodableArray = arrayValue.map { AnyCodable($0) }
                try container.encode(anyCodableArray)
            case let dictValue as [String: Any]:
                let anyCodableDict = dictValue.mapValues { AnyCodable($0) }
                try container.encode(anyCodableDict)
            default:
                let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable cannot encode value of type \(type(of: value))")
                throw EncodingError.invalidValue(value, context)
            }
        }
    }
    
    // MARK: - NavBar
    private func setupNavBar() {
        view.addSubview(navBar)
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.isStreakVisible = false
        navBar.isWelcomeTextHidden = true
        navBar.isChordIconVisible = true
        
        navBar.chordAction = { [weak self] in
            guard let self = self else { return }
            let vc = ChordRecognitionViewController()
            if let nav = self.navigationController {
                nav.pushViewController(vc, animated: true)
            } else {
                vc.modalPresentationStyle = .fullScreen
                self.present(vc, animated: true)
            }
        }
        navBar.profileAction = { [weak self] in
            guard let self = self else { return }
            let vc = UserProfileViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        }
        
        navBar.backAction = { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }
        
        NSLayoutConstraint.activate([
            navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10)
        ])
    }
    
    // MARK: - Scroll + Content stack
    private func setupScrollView() {
        view.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        
        // contentView is the vertical UIStackView that holds sections
        scrollView.addSubview(contentView)
        contentView.axis = .vertical
        contentView.spacing = Constants.sectionSpacing
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // Constrain contentView to scrollView using contentLayoutGuide and frameLayoutGuide
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: navBar.bottomAnchor, constant: 18),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // contentView to contentLayoutGuide (vertical)
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 0),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: 0),
            
            // contentView to frameLayoutGuide (horizontal sizing)
            contentView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: Constants.horizontalPadding),
            contentView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -Constants.horizontalPadding),
            
            // ensure contentView width equals frame width minus padding so stack's arranged subviews layout properly
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * Constants.horizontalPadding)
        ])
    }
    
    // MARK: - Upload Meta Section (circular thumbnail + title + Edit)
    private func addUploadMetaSection() {
        let metaStack = UIStackView()
        metaStack.axis = .horizontal
        metaStack.spacing = 14
        metaStack.alignment = .center
        metaStack.translatesAutoresizingMaskIntoConstraints = false
        
        // circular cover image
        let cover = UIImageView()
        cover.image = uploadCoverImage ?? UIImage(systemName: "music.note")
        cover.tintColor = .black
        cover.backgroundColor = UIColor(white: 0.95, alpha: 1)
        cover.clipsToBounds = true
        cover.layer.cornerRadius = 20
        cover.translatesAutoresizingMaskIntoConstraints = true
        metaCoverImgView = cover
        
        // title label
        let title = UILabel()
        title.text = uploadTitle
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .label
        title.translatesAutoresizingMaskIntoConstraints = false
        metaTitleLbl = title
        
        // edit button (shows action sheet)
        let editButton = UIButton(type: .system)
        editButton.setTitle("Edit", for: .normal)
        editButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        editButton.addTarget(self, action: #selector(showMetaEditor), for: .touchUpInside)
        
        metaStack.addArrangedSubview(cover)
        metaStack.addArrangedSubview(title)
        metaStack.addArrangedSubview(editButton)
        
        NSLayoutConstraint.activate([
            cover.widthAnchor.constraint(equalToConstant: 36),
            cover.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        contentView.addArrangedSubview(metaStack)
    }
    
    @objc private func showMetaEditor() {
        let ac = UIAlertController(title: "Edit Upload Info", message: nil, preferredStyle: .actionSheet)
        
        ac.addAction(UIAlertAction(title: "Edit Name", style: .default) { _ in
            self.askForTitle()
        })
        ac.addAction(UIAlertAction(title: "Change Cover Image", style: .default) { _ in
            self.presentImagePicker(sourceType: .photoLibrary, forCover: true)
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        // iPad popover anchor
        if let pop = ac.popoverPresentationController {
            pop.sourceView = metaCoverImgView ?? self.view
            pop.sourceRect = CGRect(x: view.bounds.midX, y: 100, width: 0, height: 0)
        }
        present(ac, animated: true)
    }
    
    private func askForTitle() {
        let ac = UIAlertController(title: "Enter Title", message: nil, preferredStyle: .alert)
        ac.addTextField { tf in
            tf.placeholder = "Song Title"
            tf.text = self.uploadTitle
        }
        ac.addAction(UIAlertAction(title: "Save", style: .default) { _ in
            let newTitle = ac.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines)
            self.uploadTitle = (newTitle?.isEmpty == false) ? newTitle! : "Untitled"
            self.metaTitleLbl?.text = self.uploadTitle
        })
        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(ac, animated: true)
    }
    
    // MARK: - Upload Box (big drag/drop area + button)
    private func setupUploadSection() {
        // container
        uploadContainer.backgroundColor = .secondarySystemBackground
        uploadContainer.layer.cornerRadius = Constants.cornerRadius
        uploadContainer.translatesAutoresizingMaskIntoConstraints = false
        
        // icon centered
        uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
        uploadIcon.tintColor = .black
        uploadIcon.contentMode = .scaleAspectFit
        uploadIcon.translatesAutoresizingMaskIntoConstraints = false
        
        // label
        uploadLabel.text = "Drag & drop or tap to upload"
        uploadLabel.font = .systemFont(ofSize: 14, weight: .regular)
        uploadLabel.textColor = .secondaryLabel
        uploadLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // upload button
        var cfg = UIButton.Configuration.filled()
        cfg.title = "Upload Files"
        cfg.image = UIImage(systemName: "camera.fill")
        cfg.baseBackgroundColor = .systemYellow
        cfg.baseForegroundColor = .black
        cfg.cornerStyle = .medium
        uploadButton.configuration = cfg
        uploadButton.translatesAutoresizingMaskIntoConstraints = false
        uploadButton.addTarget(self, action: #selector(uploadTapped), for: .touchUpInside)
        
        // add to stack
        contentView.addArrangedSubview(uploadContainer)
        contentView.addArrangedSubview(uploadButton)
        
        uploadContainer.addSubview(uploadIcon)
        uploadContainer.addSubview(uploadLabel)
        
        // constraints
        uploadContainer.heightAnchor.constraint(equalToConstant: Constants.uploadContainerHeight).isActive = true
        
        NSLayoutConstraint.activate([
            uploadIcon.centerXAnchor.constraint(equalTo: uploadContainer.centerXAnchor),
            uploadIcon.centerYAnchor.constraint(equalTo: uploadContainer.centerYAnchor, constant: -10),
            uploadIcon.widthAnchor.constraint(equalToConstant: 44),
            uploadIcon.heightAnchor.constraint(equalToConstant: 44),
            
            uploadLabel.topAnchor.constraint(equalTo: uploadIcon.bottomAnchor, constant: 8),
            uploadLabel.centerXAnchor.constraint(equalTo: uploadContainer.centerXAnchor),
            
            uploadButton.heightAnchor.constraint(equalToConstant: Constants.buttonHeight)
        ])
        
        // tap gesture for the entire container
        let tap = UITapGestureRecognizer(target: self, action: #selector(uploadTapped))
        uploadContainer.addGestureRecognizer(tap)
    }
    
    @objc private func uploadTapped() {
        showUploadOptions()
    }
    
    private func showUploadOptions() {
        let ac = UIAlertController(title: "Upload Content", message: nil, preferredStyle: .actionSheet)

        ac.addAction(UIAlertAction(title: "Take Photo", style: .default) { _ in
            self.presentImagePicker(sourceType: .camera)
        })

        ac.addAction(UIAlertAction(title: "Choose Single Photo", style: .default) { _ in
            self.presentSingleImagePicker(sourceType: .photoLibrary)
        })
        
        ac.addAction(UIAlertAction(title: "Choose Multiple Photos", style: .default) { _ in
            self.presentMultipleImagePicker()
        })

        ac.addAction(UIAlertAction(title: "Browse Files", style: .default) { _ in
            self.openFileManager()
        })

        ac.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let pop = ac.popoverPresentationController {
            pop.sourceView = uploadButton
            pop.sourceRect = uploadButton.bounds
        }

        present(ac, animated: true)
    }
    
    // MARK: - Recent Uploads (horizontal scroll)
    private func addRecentUploadsSection() {
        let header = UILabel()
        header.text = "Recent Uploads"
        header.font = .systemFont(ofSize: 18, weight: .semibold)
        header.textColor = .label
        contentView.addArrangedSubview(header)
        
        // horizontal scroll view — must give it a constrained height so UIStackView sizes it
        let horizScroll = UIScrollView()
        horizScroll.translatesAutoresizingMaskIntoConstraints = false
        horizScroll.showsHorizontalScrollIndicator = false
        contentView.addArrangedSubview(horizScroll)
        
        NSLayoutConstraint.activate([
            horizScroll.heightAnchor.constraint(equalToConstant: Constants.carouselHeight)
        ])
        
        // hStack inside scroll's contentLayoutGuide
        let hStack = UIStackView()
        hStack.axis = .horizontal
        hStack.spacing = Constants.elementSpacing
        hStack.alignment = .center
        hStack.translatesAutoresizingMaskIntoConstraints = false
        recentHStack = hStack
        
        horizScroll.addSubview(hStack)
        
        NSLayoutConstraint.activate([
            hStack.topAnchor.constraint(equalTo: horizScroll.contentLayoutGuide.topAnchor),
            hStack.bottomAnchor.constraint(equalTo: horizScroll.contentLayoutGuide.bottomAnchor),
            hStack.leadingAnchor.constraint(equalTo: horizScroll.contentLayoutGuide.leadingAnchor, constant: 10),
            hStack.trailingAnchor.constraint(equalTo: horizScroll.contentLayoutGuide.trailingAnchor, constant: -10),
            
            // ensure the stack's height matches the scroll's visible height
            hStack.heightAnchor.constraint(equalTo: horizScroll.frameLayoutGuide.heightAnchor)
        ])
    }
    
    // MARK: - Add card to recents (insert at 0)
    private func addRecentUploadCard(title: String, image: UIImage?) {
        guard let hStack = recentHStack else { return }
        let card = makeRecentCard(title: title, image: image)
        // insert at start
        hStack.insertArrangedSubview(card, at: 0)
    }
    
    private func makeRecentCard(title: String, image: UIImage?) -> UIView {
        // card container (with shadow)
        let card = UIButton(type: .system)
        card.translatesAutoresizingMaskIntoConstraints = false
        card.backgroundColor = .systemBackground
        card.layer.cornerRadius = Constants.cornerRadius
        card.clipsToBounds = false // allow shadow
        card.layer.shadowColor = UIColor.black.cgColor
        card.layer.shadowOpacity = 0.12
        card.layer.shadowRadius = 6
        card.layer.shadowOffset = CGSize(width: 0, height: 3)
        
        // circular inner image (center)
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = (image == nil) ? .scaleAspectFill : .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = 20 // circular image radius
        iv.tintColor = .black
        iv.image = image ?? UIImage(systemName: "music.note")
        iv.backgroundColor = image == nil ? UIColor(white: 0.97, alpha: 1) : .clear
        
        // title label bottom
        let titleLbl = UILabel()
        titleLbl.translatesAutoresizingMaskIntoConstraints = false
        titleLbl.text = title
        titleLbl.font = .systemFont(ofSize: 14, weight: .medium)
        titleLbl.textAlignment = .center
        titleLbl.numberOfLines = 2
        
        card.addSubview(iv)
        card.addSubview(titleLbl)
        
        NSLayoutConstraint.activate([
            card.widthAnchor.constraint(equalToConstant: Constants.cardSize.width),
            card.heightAnchor.constraint(equalToConstant: Constants.cardSize.height),
            
            // center iv horizontally, slightly above center
            iv.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            iv.centerYAnchor.constraint(equalTo: card.centerYAnchor, constant: -10),
            iv.widthAnchor.constraint(equalToConstant: 80),
            iv.heightAnchor.constraint(equalToConstant: 80),
            
            // title at bottom with small padding
            titleLbl.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 6),
            titleLbl.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -6),
            titleLbl.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -8)
        ])
        
        // action: navigate to detail when tapped
        card.addAction(UIAction(handler: { _ in
            let vc = UploadPageNextViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        }), for: .touchUpInside)
        
        return card
    }
    
    // MARK: - Image picker helper
    private func presentImagePicker(sourceType: UIImagePickerController.SourceType, forCover: Bool = false) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        picker.sourceType = sourceType
        picker.view.tag = forCover ? 999 : 0
        present(picker, animated: true)
    }
    
    private func presentSingleImagePicker(sourceType: UIImagePickerController.SourceType) {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.allowsEditing = true
        picker.sourceType = sourceType
        picker.view.tag = 0
        present(picker, animated: true)
    }
    
    private func presentMultipleImagePicker() {
        // Reset selected images
        selectedImages.removeAll()
        isMultiImageSelection = true
        
        // Show image picker for multiple selection
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.view.tag = 1000 // Special tag for multi-image selection
        
        // Present with a message
        present(picker, animated: true) {
            // Show an alert explaining the multi-selection process
            let alert = UIAlertController(
                title: "Select Multiple Images",
                message: "Select multiple images one by one. They will be automatically converted to a scanned PDF and uploaded.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            picker.present(alert, animated: true)
        }
    }
    
    // MARK: - Navigation Helper
    private func navigateToNextPage(with scanId: Int64, resultURL: String) {
        DispatchQueue.main.async {
            let vc = UploadPageNextViewController()
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
}

// MARK: - UIImagePickerControllerDelegate
extension UploadScreen: UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDocumentPickerDelegate {
    
    func openFileManager() {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [
                .pdf,
                .data,
                .item
            ],
            asCopy: true
        )
        
        picker.delegate = self
        picker.allowsMultipleSelection = false
        present(picker, animated: true)
    }
    
    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        guard let fileURL = urls.first else { return }

        do {
            let data = try Data(contentsOf: fileURL)
            currentUploadData = data
            currentFileName = fileURL.lastPathComponent
            currentFileType = "application/pdf"

            // Show loading state
            uploadIcon.image = UIImage(systemName: "arrow.clockwise")
            uploadLabel.text = "Processing upload..."

            Task {
                do {
                    print("Starting PDF upload task...")
                    try await saveUploadToDatabase(
                        imageData: data,
                        fileName: currentFileName,
                        fileType: currentFileType
                    )
                    
                    print("PDF upload completed successfully!")
                    
                    // Refresh recent uploads
                    await self.loadRecentUploadsFromDB()
                    
                    // Update UI on main thread
                    DispatchQueue.main.async {
                        // Show success
                        self.uploadIcon.image = UIImage(systemName: "checkmark.circle.fill")
                        self.uploadLabel.text = "Upload completed!"
                        
                        // Reset after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
                            self.uploadLabel.text = "Drag & drop or tap to upload"
                        }
                    }
                } catch {
                    print("PDF upload failed with error: \(error)")
                    print("Error details: \(error.localizedDescription)")
                    
                    DispatchQueue.main.async {
                        // Show error with more details
                        self.uploadIcon.image = UIImage(systemName: "exclamationmark.triangle")
                        self.uploadLabel.text = "Upload failed"
                        
                        // Reset after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
                            self.uploadLabel.text = "Drag & drop or tap to upload"
                        }
                        
                        // Show error alert with more details
                        let alert = UIAlertController(
                            title: "Upload Failed",
                            message: "Error: \(error.localizedDescription)\n\nPlease check your connection and try again.",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        self.present(alert, animated: true)
                    }
                }
            }
        } catch {
            print("Failed to read file:", error)
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Error",
                    message: "Failed to read file: \(error.localizedDescription)",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }
    }

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        let picked = (info[.editedImage] ?? info[.originalImage]) as? UIImage
        picker.dismiss(animated: true)
        
        if picker.view.tag == 999 {
            // user changed the meta cover image
            uploadCoverImage = picked
            metaCoverImgView?.image = uploadCoverImage
            return
        }
        
        if picker.view.tag == 1000 {
            // Multi-image selection mode
            guard let image = picked else { return }
            
            // Add image to selected images array
            selectedImages.append(image)
            
            // Show how many images selected
            DispatchQueue.main.async {
                self.uploadIcon.image = UIImage(systemName: "photo.stack")
                self.uploadLabel.text = "Selected \(self.selectedImages.count) image(s). Tap 'Upload Files' to convert to scanned PDF."
            }
            
            // Ask if user wants to add more images
            let alert = UIAlertController(
                title: "Add More Images?",
                message: "Selected \(selectedImages.count) image(s). Do you want to add more images?",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Add More", style: .default) { _ in
                self.presentMultipleImagePicker()
            })
            
            alert.addAction(UIAlertAction(title: "Done", style: .default) { _ in
                // Convert images to scanned PDF and upload
                self.processSelectedImagesAndUpload()
            })
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                // Clear selected images
                self.selectedImages.removeAll()
                self.isMultiImageSelection = false
                self.uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
                self.uploadLabel.text = "Drag & drop or tap to upload"
            })
            
            self.present(alert, animated: true)
            return
        }
        
        // Normal single image upload flow
        guard let image = picked else { return }
        
        // Process image for scanned look
        let processedImage: UIImage
        if let thresholdedImage = applySimpleThreshold(image, threshold: 0.6) {
            processedImage = thresholdedImage
        } else {
            processedImage = processImageForScanLook(image)
        }
        
        // Convert single processed image to scanned PDF
        guard let pdfData = convertImagesToPDF(images: [processedImage]) else {
            DispatchQueue.main.async {
                let alert = UIAlertController(
                    title: "Error",
                    message: "Failed to convert image to scanned PDF.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
            return
        }
        
        // Update upload data with PDF
        currentUploadData = pdfData
        currentFileName = "scanned_image_\(Date().timeIntervalSince1970).pdf"
        currentFileType = "application/pdf"
        
        // Show loading state
        uploadIcon.image = UIImage(systemName: "arrow.clockwise")
        uploadLabel.text = "Processing image to scanned PDF..."
        
        // Upload the PDF
        Task {
            do {
                print("Starting single image to scanned PDF upload task...")
                try await saveUploadToDatabase(
                    imageData: pdfData,
                    fileName: currentFileName,
                    fileType: currentFileType
                )
                
                print("Single image scanned PDF upload completed successfully!")
                
                // Refresh recent uploads
                await self.loadRecentUploadsFromDB()
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    // Show success
                    self.uploadIcon.image = UIImage(systemName: "checkmark.circle.fill")
                    self.uploadLabel.text = "Scanned PDF created and uploaded!"
                    
                    // Reset after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
                        self.uploadLabel.text = "Drag & drop or tap to upload"
                    }
                }
            } catch {
                print("Single image scanned PDF upload failed with error: \(error)")
                print("Error details: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    // Show error with more details
                    self.uploadIcon.image = UIImage(systemName: "exclamationmark.triangle")
                    self.uploadLabel.text = "Upload failed"
                    
                    // Reset after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        self.uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
                        self.uploadLabel.text = "Drag & drop or tap to upload"
                    }
                    
                    // Show error alert with more details
                    let alert = UIAlertController(
                        title: "Upload Failed",
                        message: "Error: \(error.localizedDescription)\n\nPlease check your connection and try again.",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
        
        // If in multi-image mode and no images selected, reset
        if isMultiImageSelection && selectedImages.isEmpty {
            isMultiImageSelection = false
            DispatchQueue.main.async {
                self.uploadIcon.image = UIImage(systemName: "arrow.up.to.line")
                self.uploadLabel.text = "Drag & drop or tap to upload"
            }
        }
    }
}
