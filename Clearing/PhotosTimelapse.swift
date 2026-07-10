//  PhotosTimelapse.swift
//  Clearing

import SwiftUI
import UIKit
import Combine
import AVFoundation
import CoreVideo
import Photos

// MARK: - Progress photos

struct PhotoArea {
    let key: String
    let title: String
    let emoji: String
}

enum PhotoAreas {
    static let all: [PhotoArea] = [
        PhotoArea(key: "face", title: "Face", emoji: "🌷"),
        PhotoArea(key: "chest", title: "Chest", emoji: "💗"),
        PhotoArea(key: "armpits", title: "Armpits", emoji: "🫶"),
        PhotoArea(key: "bikini", title: "Bikini", emoji: "🌸"),
        PhotoArea(key: "removal", title: "Removal", emoji: "🪞"),
        PhotoArea(key: "habits", title: "Habits", emoji: "🍵"),
    ]
}

struct PhotosView: View {
    @EnvironmentObject var store: AppStore
    @State private var selectedArea = "face"
    @State private var showCamera = false
    @State private var cameraUnavailable = false
    @State private var viewerPhoto: ProgressPhoto?
    @State private var showTimelapse = false
    @State private var showDemo = false

    private var photosForArea: [ProgressPhoto] { store.photos(for: selectedArea) }
    private var areaTitle: String { PhotoAreas.all.first { $0.key == selectedArea }?.title ?? "" }
    private var todayHasPhoto: Bool {
        photosForArea.contains { $0.dateKey == store.dateKey(Date()) }
    }
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Progress photos")
                        .font(.system(.title3, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                    Text("A private, on-device timeline for each area. Nothing leaves your phone.")
                        .font(.footnote).foregroundColor(.soft)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(PhotoAreas.all, id: \.key) { area in
                                let selected = selectedArea == area.key
                                Button { selectedArea = area.key } label: {
                                    VStack(spacing: 2) {
                                        Text(area.emoji)
                                        Text(area.title).font(.caption.weight(.bold))
                                    }
                                    .foregroundColor(selected ? .white : .soft)
                                    .frame(width: 72)
                                    .padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 13)
                                        .fill(selected ? Color.bodyCoral : Color.white.opacity(0.75)))
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    HStack(spacing: 10) {
                        Button {
                            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                                showCamera = true
                            } else {
                                cameraUnavailable = true
                            }
                        } label: {
                            Label(todayHasPhoto ? "Retake today's photo" : "Take today's photo", systemImage: "camera.fill")
                                .font(.subheadline.weight(.heavy))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Capsule().fill(Color.bodyCoral))
                        }

                        Button {
                            showTimelapse = true
                        } label: {
                            Image(systemName: "play.rectangle.fill")
                                .font(.subheadline.weight(.heavy))
                                .foregroundColor(photosForArea.count < 2 ? .faint : .roseDeep)
                                .frame(width: 48, height: 48)
                                .background(Circle().fill(Color.white))
                        }
                        .disabled(photosForArea.count < 2)
                    }

                    if photosForArea.isEmpty {
                        VStack(spacing: 10) {
                            Text("📸").font(.system(size: 32))
                            Text("No photos yet for \(areaTitle)")
                                .font(.subheadline.weight(.semibold)).foregroundColor(.ink)
                            Text("Take your first daily photo to start tracking progress.")
                                .font(.caption).foregroundColor(.soft)
                                .multilineTextAlignment(.center)
                            Button { showDemo = true } label: {
                                Label("See how the timelapse works", systemImage: "play.circle.fill")
                                    .font(.caption.weight(.heavy))
                                    .foregroundColor(.roseDeep)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(Color.roseTint))
                            }
                            .padding(.top, 2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(RoundedRectangle(cornerRadius: 20).fill(Color.white))
                    } else {
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(photosForArea) { photo in
                                Button { viewerPhoto = photo } label: {
                                    PhotoThumb(photo: photo)
                                }
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 30)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(overlayImage: store.previousPhoto(for: selectedArea, excluding: store.dateKey(Date())).flatMap(store.image(for:))) { image in
                store.savePhoto(image, area: selectedArea)
            }
            .ignoresSafeArea()
        }
        .sheet(item: $viewerPhoto) { photo in
            PhotoViewerSheet(photo: photo)
        }
        .sheet(isPresented: $showTimelapse) {
            if let area = PhotoAreas.all.first(where: { $0.key == selectedArea }) {
                TimelapseView(area: area)
            }
        }
        .sheet(isPresented: $showDemo) {
            if let area = PhotoAreas.all.first(where: { $0.key == selectedArea }) {
                DemoTimelapseView(area: area)
            }
        }
        .alert("Camera not available", isPresented: $cameraUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device (or simulator) doesn't have a camera available.")
        }
    }
}

struct PhotoThumb: View {
    @EnvironmentObject var store: AppStore
    let photo: ProgressPhoto

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let img = store.image(for: photo) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Color.roseTint
            }
            Text(DateKeyFormat.displayString(from: photo.dateKey))
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.white)
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color.black.opacity(0.45))
                .clipShape(Capsule())
                .padding(5)
        }
        .frame(height: 110)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct PhotoViewerSheet: View {
    @EnvironmentObject var store: AppStore
    let photo: ProgressPhoto
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        VStack(spacing: 16) {
            if let img = store.image(for: photo) {
                Image(uiImage: img).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            Text(DateKeyFormat.displayString(from: photo.dateKey))
                .font(.system(.headline, design: .serif).weight(.semibold))
                .foregroundColor(.ink)
            Button(role: .destructive) {
                confirmDelete = true
            } label: {
                Label("Delete photo", systemImage: "trash")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.roseDeep)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Capsule().fill(Color.roseTint))
            }
            Spacer()
        }
        .padding(24)
        .presentationDetents([.large])
        .confirmationDialog("Delete this photo?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.deletePhoto(photo)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

// MARK: - Timelapse

struct RangeSlider: View {
    @Binding var lowerValue: Double
    @Binding var upperValue: Double
    let bounds: ClosedRange<Double>
    var accent: Color = .bodyCoral
    private let thumbSize: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            let trackWidth = max(0, geo.size.width - thumbSize)
            let span = bounds.upperBound - bounds.lowerBound
            let lowerX = span > 0 ? CGFloat((lowerValue - bounds.lowerBound) / span) * trackWidth : 0
            let upperX = span > 0 ? CGFloat((upperValue - bounds.lowerBound) / span) * trackWidth : trackWidth

            ZStack(alignment: .leading) {
                Capsule().fill(Color.lineC).frame(height: 4)
                    .offset(x: thumbSize / 2)
                Capsule().fill(accent).frame(width: max(0, upperX - lowerX), height: 4)
                    .offset(x: lowerX + thumbSize / 2)

                thumb.offset(x: lowerX)
                    .gesture(DragGesture().onChanged { value in
                        guard span > 0 else { return }
                        let raw = bounds.lowerBound + Double((value.location.x - thumbSize / 2) / trackWidth) * span
                        lowerValue = min(max(raw.rounded(), bounds.lowerBound), upperValue)
                    })

                thumb.offset(x: upperX)
                    .gesture(DragGesture().onChanged { value in
                        guard span > 0 else { return }
                        let raw = bounds.lowerBound + Double((value.location.x - thumbSize / 2) / trackWidth) * span
                        upperValue = max(min(raw.rounded(), bounds.upperBound), lowerValue)
                    })
            }
        }
    }

    private var thumb: some View {
        Circle().fill(Color.white)
            .overlay(Circle().stroke(accent, lineWidth: 3))
            .frame(width: thumbSize, height: thumbSize)
            .shadow(color: Color.ink.opacity(0.15), radius: 2, y: 1)
    }
}

enum TimelapseSpeed {
    /// Scales flip speed to photo count so playback stays roughly this many seconds long,
    /// without ever flickering too fast or crawling too slow.
    static func interval(forFrameCount count: Int, targetDuration: Double = 6.0,
                         minInterval: Double = 0.12, maxInterval: Double = 0.6) -> Double {
        guard count > 1 else { return maxInterval }
        return min(max(targetDuration / Double(count), minInterval), maxInterval)
    }
}

struct DemoTimelapseView: View {
    let area: PhotoArea
    @Environment(\.dismiss) private var dismiss

    private let frameCount = 30
    @State private var index: Double = 0
    @State private var isPlaying = true

    private let playTimer = Timer.publish(every: TimelapseSpeed.interval(forFrameCount: 30), on: .main, in: .common).autoconnect()

    private var frameIndex: Int { min(frameCount - 1, max(0, Int(index.rounded()))) }
    private var progress: Double { Double(frameIndex) / Double(frameCount - 1) }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.roseDeep)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.roseTint))
                    }
                    Spacer()
                    Text("Example timelapse")
                        .font(.system(.headline, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                    Spacer()
                    Color.clear.frame(width: 30, height: 30)
                }

                Text("Illustrated example — once you've taken a few \(area.title.lowercased()) photos, your real timeline will scrub and play just like this.")
                    .font(.caption).foregroundColor(.soft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)

                DemoFrameView(progress: progress)
                    .frame(maxHeight: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Text("Day \(frameIndex + 1) of \(frameCount) · example")
                    .font(.caption.weight(.bold)).foregroundColor(.soft)

                Slider(value: $index, in: 0...Double(frameCount - 1), step: 1) { editing in
                    if editing { isPlaying = false }
                }
                .tint(.bodyCoral)

                Button {
                    if frameIndex == frameCount - 1 { index = 0 }
                    isPlaying.toggle()
                } label: {
                    Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                        .font(.subheadline.weight(.heavy))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.bodyCoral))
                }

                Spacer()
            }
            .padding(20)
        }
        .onReceive(playTimer) { _ in
            guard isPlaying else { return }
            let next = frameIndex + 1
            index = Double(next > frameCount - 1 ? 0 : next)
        }
    }
}

struct DemoFrameView: View {
    let progress: Double   // 0...1

    var body: some View {
        ZStack {
            LinearGradient(colors: [
                Color(hex: 0xE7D3DC),
                Color.rose.opacity(0.55 + progress * 0.35),
                Color.amGold.opacity(0.25 + progress * 0.35),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle()
                .stroke(Color.white.opacity(0.5), lineWidth: 7)
                .frame(width: 140, height: 140)
            Circle()
                .trim(from: 0, to: 0.3 + progress * 0.7)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 140, height: 140)
                .animation(.easeInOut(duration: 0.4), value: progress)

            VStack(spacing: 4) {
                Text("✨").font(.system(size: 30)).opacity(0.35 + progress * 0.65)
                Text("\(Int(progress * 100))% glow")
                    .font(.system(.subheadline, design: .serif).weight(.bold))
                    .foregroundColor(.white)
            }
        }
    }
}

struct TimelapseView: View {
    @EnvironmentObject var store: AppStore
    let area: PhotoArea
    @Environment(\.dismiss) private var dismiss

    @State private var photos: [ProgressPhoto] = []   // oldest -> newest, full history
    @State private var images: [UIImage] = []          // parallel to photos
    @State private var rangeStart: Double = 0           // trim handles, indices into photos
    @State private var rangeEnd: Double = 0
    @State private var index: Double = 0                // scrub/playback position within the trimmed range
    @State private var isPlaying = false
    @State private var isExporting = false
    @State private var showExportError = false
    @State private var exportErrorMessage = ""
    @State private var showSavedAlert = false
    @State private var elapsedSincePlay: TimeInterval = 0

    // Fast fixed tick; actual advance rate adapts to trimmedPhotos.count via elapsedSincePlay,
    // so speed stays correct even as the trim range changes live.
    private let heartbeat = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    private var playInterval: Double { TimelapseSpeed.interval(forFrameCount: trimmedPhotos.count) }

    private var trimStart: Int { photos.isEmpty ? 0 : min(Int(rangeStart.rounded()), photos.count - 1) }
    private var trimEnd: Int { photos.isEmpty ? 0 : min(Int(rangeEnd.rounded()), photos.count - 1) }
    private var trimmedPhotos: [ProgressPhoto] { photos.isEmpty ? [] : Array(photos[trimStart...trimEnd]) }
    private var trimmedImages: [UIImage] { images.isEmpty ? [] : Array(images[trimStart...trimEnd]) }

    private var frameIndex: Int {
        guard !trimmedPhotos.isEmpty else { return 0 }
        return min(trimmedPhotos.count - 1, max(0, Int(index.rounded())))
    }
    private var currentImage: UIImage? { trimmedImages.indices.contains(frameIndex) ? trimmedImages[frameIndex] : nil }
    private var currentPhoto: ProgressPhoto? { trimmedPhotos.indices.contains(frameIndex) ? trimmedPhotos[frameIndex] : nil }
    private var rangeLabel: String {
        guard let first = trimmedPhotos.first, let last = trimmedPhotos.last else { return "" }
        return "\(trimmedPhotos.count) photos · \(DateKeyFormat.displayString(from: first.dateKey)) – \(DateKeyFormat.displayString(from: last.dateKey))"
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: [.bgTop, .bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.heavy))
                            .foregroundColor(.roseDeep)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Color.roseTint))
                    }
                    Spacer()
                    Text("\(area.emoji) \(area.title) timelapse")
                        .font(.system(.headline, design: .serif).weight(.semibold))
                        .foregroundColor(.ink)
                    Spacer()
                    Color.clear.frame(width: 30, height: 30)
                }

                ZStack {
                    RoundedRectangle(cornerRadius: 20).fill(Color.black)
                    if let img = currentImage {
                        Image(uiImage: img).resizable().scaledToFit()
                    } else {
                        ProgressView().tint(.white)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(maxHeight: 380)

                if let photo = currentPhoto {
                    Text("\(DateKeyFormat.displayString(from: photo.dateKey)) · \(frameIndex + 1) of \(trimmedPhotos.count)")
                        .font(.caption.weight(.bold)).foregroundColor(.soft)
                }

                if photos.count > 1 {
                    Slider(value: $index, in: 0...Double(max(0, trimmedPhotos.count - 1)), step: 1) { editing in
                        if editing { isPlaying = false }
                    }
                    .tint(.bodyCoral)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("TRIM RANGE")
                                .font(.caption2.weight(.heavy)).foregroundColor(.soft)
                            Spacer()
                            Text(rangeLabel)
                                .font(.caption2).foregroundColor(.faint)
                        }
                        RangeSlider(lowerValue: $rangeStart, upperValue: $rangeEnd,
                                    bounds: 0...Double(photos.count - 1), accent: .bodyCoral)
                            .frame(height: 26)
                        HStack(spacing: 8) {
                            presetChip("All") { applyPreset(days: nil) }
                            presetChip("Last 7 days") { applyPreset(days: 7) }
                            presetChip("Last 30 days") { applyPreset(days: 30) }
                        }
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                } else {
                    Text("Take at least 2 photos of \(area.title.lowercased()) to build a timelapse.")
                        .font(.caption).foregroundColor(.soft)
                }

                HStack(spacing: 12) {
                    Button {
                        if frameIndex == trimmedPhotos.count - 1 { index = 0 }
                        isPlaying.toggle()
                    } label: {
                        Label(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill")
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(Color.bodyCoral))
                    }
                    .disabled(trimmedPhotos.count < 2)

                    Button {
                        exportVideo()
                    } label: {
                        Label(isExporting ? "Exporting…" : "Export", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.heavy))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Capsule().fill(isExporting ? Color.faint : Color.rose))
                    }
                    .disabled(trimmedPhotos.count < 2 || isExporting)
                }

                if isExporting {
                    ProgressView().tint(.rose)
                }

                Spacer()
            }
            .padding(20)
        }
        .onAppear(perform: load)
        .onChange(of: rangeStart) { _, _ in isPlaying = false; index = 0; elapsedSincePlay = 0 }
        .onChange(of: rangeEnd) { _, _ in isPlaying = false; index = 0; elapsedSincePlay = 0 }
        .onReceive(heartbeat) { _ in
            guard isPlaying, trimmedPhotos.count > 1 else { return }
            elapsedSincePlay += 0.05
            guard elapsedSincePlay >= playInterval else { return }
            elapsedSincePlay = 0
            let next = frameIndex + 1
            index = Double(next > trimmedPhotos.count - 1 ? 0 : next)
        }
        .alert("Saved to Photos ♡", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) {}
        }
        .alert("Export failed", isPresented: $showExportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage)
        }
    }

    private func presetChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.roseDeep)
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Capsule().fill(Color.roseTint))
        }
    }

    private func load() {
        photos = store.photos(for: area.key).sorted { $0.dateKey < $1.dateKey }
        images = photos.compactMap { store.image(for: $0) }
        rangeStart = 0
        rangeEnd = Double(max(0, photos.count - 1))
        index = 0
    }

    private func applyPreset(days: Int?) {
        guard !photos.isEmpty else { return }
        guard let days else {
            rangeStart = 0
            rangeEnd = Double(photos.count - 1)
            return
        }
        let cutoff = Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: Date())) ?? .distantPast
        let cutoffKey = store.dateKey(cutoff)
        let firstIdx = photos.firstIndex { $0.dateKey >= cutoffKey } ?? 0
        rangeStart = Double(firstIdx)
        rangeEnd = Double(photos.count - 1)
    }

    private func exportVideo() {
        isPlaying = false
        isExporting = true
        TimelapseRenderer.export(images: trimmedImages) { result in
            isExporting = false
            switch result {
            case .success(let url):
                saveToPhotos(url)
            case .failure(let error):
                exportErrorMessage = error.localizedDescription
                showExportError = true
            }
        }
    }

    private func saveToPhotos(_ url: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                guard status == .authorized || status == .limited else {
                    exportErrorMessage = "Photos access is needed to save the timelapse. Enable it in Settings → Privacy → Photos."
                    showExportError = true
                    try? FileManager.default.removeItem(at: url)
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }) { success, error in
                    DispatchQueue.main.async {
                        if success {
                            showSavedAlert = true
                        } else {
                            exportErrorMessage = error?.localizedDescription ?? "Could not save the video."
                            showExportError = true
                        }
                        try? FileManager.default.removeItem(at: url)
                    }
                }
            }
        }
    }
}

enum TimelapseRenderer {
    enum RenderError: LocalizedError {
        case noImages
        case writerSetupFailed
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .noImages: return "No photos to render."
            case .writerSetupFailed: return "Couldn't set up the video writer."
            case .writeFailed: return "Something went wrong while writing the video."
            }
        }
    }

    nonisolated static func export(images: [UIImage], fps: Int32 = 2, completion: @escaping (Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let url = try renderSync(images: images, fps: fps)
                DispatchQueue.main.async { completion(.success(url)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    nonisolated private static func renderSync(images: [UIImage], fps: Int32) throws -> URL {
        guard let first = images.first else { throw RenderError.noImages }

        let maxDim: CGFloat = 1280
        let scale = min(1, maxDim / max(first.size.width, first.size.height))
        let rawWidth = Int((first.size.width * scale).rounded())
        let rawHeight = Int((first.size.height * scale).rounded())
        let width = max(2, rawWidth - rawWidth % 2)
        let height = max(2, rawHeight - rawHeight % 2)

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("timelapse-\(UUID().uuidString).mp4")

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = false

        let pixelBufferAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: pixelBufferAttrs)

        guard writer.canAdd(input) else { throw RenderError.writerSetupFailed }
        writer.add(input)

        guard writer.startWriting() else { throw RenderError.writerSetupFailed }
        writer.startSession(atSourceTime: .zero)

        let frameDuration = CMTime(value: 1, timescale: fps)
        var frameCount: Int64 = 0

        for image in images {
            guard let buffer = pixelBuffer(from: image, width: width, height: height) else { continue }
            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.01)
            }
            let time = CMTimeMultiply(frameDuration, multiplier: Int32(frameCount))
            adaptor.append(buffer, withPresentationTime: time)
            frameCount += 1
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()

        guard writer.status == .completed else { throw RenderError.writeFailed }
        return outputURL
    }

    nonisolated private static func pixelBuffer(from image: UIImage, width: Int, height: Int) -> CVPixelBuffer? {
        let upright = normalized(image)
        guard let cgImage = upright.cgImage else { return nil }

        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs as CFDictionary, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer),
                                      width: width, height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                                      space: colorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else { return nil }

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        let imgSize = CGSize(width: cgImage.width, height: cgImage.height)
        let fitScale = min(CGFloat(width) / imgSize.width, CGFloat(height) / imgSize.height)
        let drawSize = CGSize(width: imgSize.width * fitScale, height: imgSize.height * fitScale)
        let origin = CGPoint(x: (CGFloat(width) - drawSize.width) / 2, y: (CGFloat(height) - drawSize.height) / 2)
        context.draw(cgImage, in: CGRect(origin: origin, size: drawSize))

        return buffer
    }

    nonisolated private static func normalized(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up { return image }
        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: image.size)) }
    }
}

struct CameraPicker: UIViewControllerRepresentable {
    var overlayImage: UIImage? = nil
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        if let overlayImage {
            let overlay = UIImageView(image: overlayImage)
            overlay.frame = UIScreen.main.bounds
            overlay.contentMode = .scaleAspectFit
            overlay.clipsToBounds = true
            overlay.alpha = 0.3
            overlay.isUserInteractionEnabled = false
            picker.cameraOverlayView = overlay
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

