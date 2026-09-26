import SwiftUI
import AVFoundation
import Observation

/// 고스트 오버레이: 카메라 화면 위에 참고 사진을 반투명하게 겹쳐 구도를 맞춥니다.
struct GhostOverlayView: View {
    let frame: Frame

    @State private var camera = CameraController()
    @State private var opacity: Double = 0.4
    @State private var highContrast = false

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Color.black

                switch camera.status {
                case .running:
                    CameraPreview(session: camera.session)
                case .denied:
                    message("카메라 권한이 필요해요. 설정에서 허용해 주세요.")
                case .unavailable:
                    message("이 기기(시뮬레이터)에서는 카메라를 쓸 수 없어요.\n참고 사진만 겹쳐서 보여드려요.")
                case .idle:
                    ProgressView().tint(.white)
                }

                ghost
                    .opacity(opacity)
                    .allowsHitTesting(false)

                ThirdsGrid()
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                    .allowsHitTesting(false)

                ViewfinderCorners(length: 18)
                    .stroke(VF.Palette.amber, style: StrokeStyle(lineWidth: 2, lineCap: .square))
                    .padding(10)
                    .allowsHitTesting(false)
            }
            .aspectRatio(CGFloat(frame.aspectRatio), contentMode: .fit)
            .clipped()

            HStack(spacing: 10) {
                Image(systemName: "square.on.square.dashed")
                    .foregroundStyle(Color.white.opacity(0.7))
                Slider(value: $opacity, in: 0...0.85)
                    .tint(VF.Palette.amber)
                Text(verbatim: "\(Int(opacity * 100))%")
                    .font(VF.Typeface.mono(11))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .frame(width: 40, alignment: .trailing)
            }

            Toggle("고대비 윤곽으로 보기", isOn: $highContrast)
                .font(VF.Typeface.label(13))
                .foregroundStyle(Color.white)
                .tint(VF.Palette.amber)
        }
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }

    @ViewBuilder
    private var ghost: some View {
        if highContrast {
            FramePhotoView(frame: frame)
                .saturation(0)
                .contrast(1.9)
        } else {
            FramePhotoView(frame: frame)
        }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(VF.Typeface.body(13))
            .foregroundStyle(Color.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .padding(24)
    }
}

/// 삼분할 안내선
struct ThirdsGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for i in 1...2 {
            let x = rect.minX + rect.width * CGFloat(i) / 3
            p.move(to: CGPoint(x: x, y: rect.minY))
            p.addLine(to: CGPoint(x: x, y: rect.maxY))
            let y = rect.minY + rect.height * CGFloat(i) / 3
            p.move(to: CGPoint(x: rect.minX, y: y))
            p.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return p
    }
}

/// 후면 카메라 세션 관리
@Observable
final class CameraController {
    enum Status { case idle, running, denied, unavailable }

    var status: Status = .idle
    let session = AVCaptureSession()

    private let queue = DispatchQueue(label: "viewfinder.camera")
    @ObservationIgnored private var configured = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        self.configureAndRun()
                    } else {
                        self.status = .denied
                    }
                }
            }
        default:
            status = .denied
        }
    }

    func stop() {
        let session = self.session
        queue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configureAndRun() {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            status = .unavailable
            return
        }
        queue.async {
            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .photo
                if self.session.canAddInput(input) { self.session.addInput(input) }
                self.session.commitConfiguration()
                self.configured = true
            }
            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.status = .running }
        }
    }
}

/// AVCaptureVideoPreviewLayer를 SwiftUI로
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            // layerClass를 AVCaptureVideoPreviewLayer로 지정했으므로 항상 성공합니다.
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
