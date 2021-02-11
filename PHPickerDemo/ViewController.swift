import UIKit
import PhotosUI
import AVKit

// https://developer.apple.com/documentation/photokit/selecting_photos_and_videos_in_ios
// https://qiita.com/justin999/items/7685f0216ba68c39956c
// https://developer.apple.com/documentation/photokit/phpickerviewcontroller
class ViewController: UIViewController {
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var pathLabel: UILabel!
  var currentItemProvider: NSItemProvider!
  var videoIdentifier: String = "" // 動画を一意に識別するID
  var thumbnail: UIImage?
  var playerController = AVPlayerViewController()
  var player = AVPlayer()

  /// Select Videoを押した時に写真・動画選択UIを表示する
  @IBAction func presentPickerForVideos(_ sender: Any) {
    // 初回、ユーザーにアクセス権限を要求する
    let requiredAccessLevel: PHAccessLevel = .readWrite // or .addOnly
    PHPhotoLibrary.requestAuthorization(for: requiredAccessLevel) { authorizationStatus in
      switch authorizationStatus {
      case .limited:
        print("limited authorization granted")
      case .authorized:
        print("full authorization granted")
      default:
        print("Unimplemented")
      }
    }
    
    let photoLibrary = PHPhotoLibrary.shared()
    var configuration = PHPickerConfiguration(photoLibrary: photoLibrary)
    configuration.filter = .videos
    configuration.selectionLimit = 1
    // ここで.currentに設定しない場合、システムがどのバージョンの動画を読み込むかの判定に時間がかかるため、
    // 数秒のタイムラグが発生します。ここで.currentを指定しておけば、1秒以内に動画を再生させることができます。
    // https://qiita.com/justin999/items/7685f0216ba68c39956c
    configuration.preferredAssetRepresentationMode = .current
                        
    let picker = PHPickerViewController(configuration: configuration) // PHPickerViewControllerはiOS14で追加された
    picker.delegate = self
    present(picker, animated: true)
  }
  
  /// Play Videoボタンを押した時に動画を再生
  @IBAction func playVideo(_ sender: Any) {
    // Audio sessionを動画再生向けのものに設定し、activeにする
    let audioSession = AVAudioSession.sharedInstance()
    do {
      try audioSession.setCategory(.playback, mode: .moviePlayback)
    } catch {
      print("Setting category to AVAudioSessionCategoryPlayback failed.")
    }
    do {
      try audioSession.setActive(true)
      print("Audio session set active !!")
    } catch {
    }
    // 動画のlocalIdentifierを使ってカメラロールから動画を読み込み、再生する
    let assets = PHAsset.fetchAssets(withLocalIdentifiers: [videoIdentifier], options: nil)
    if assets.count == 0 {return}
    // PHImageManagerを使ってアセットをplayerItemに変換
    let manager = PHImageManager()
    assets.enumerateObjects({(obj, index, stop) -> Void in
      let asset = assets[index]
      manager.requestPlayerItem(forVideo: asset, options: nil, resultHandler: {(playerItem, info) -> Void in
        // 再生
        if let playerItem = playerItem {
          self.player.replaceCurrentItem(with: playerItem)
          self.playerController.player = self.player
          self.present(self.playerController, animated: true) {
              self.player.play()
          }
        }
      })
    })
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    displayThumbnail()
  }
}

private extension ViewController {
  /// 動画からサムネイルを生成して表示する
  func displayThumbnail() {
    guard let typeIdentifier = currentItemProvider!.registeredTypeIdentifiers.first else { return }
    
    if currentItemProvider!.hasItemConformingToTypeIdentifier(typeIdentifier) {
      // not provider.loadInPlaceFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] (url, success, error) in
      // provider.loadFileRepresentation should be used
      // PHPickerConfiguration.preferredAssetRepresentationMode should be set .current, otherwise loading takes too long
      // https://developer.apple.com/forums/thread/652695?answerId=629922022#629922022
      
      // itemProvider.loadFileRepresentationを使うべきという情報があるが、
      // handler内でのみ使用できる。外で使用するにはitemProvider.loadItemでないと使用できない。外で使用する必要があるか？
      currentItemProvider!.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] (url, error) in
//      itemProvider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { [weak self] (url, error) in
        if let url = url as? URL {
          print(url)
          let asset = AVURLAsset(url: url)
          // サムネイル生成
          let imgGenerator = AVAssetImageGenerator(asset: asset)
          imgGenerator.appliesPreferredTrackTransform = true
          do {
            let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
            self?.thumbnail = UIImage(cgImage: cgImage)
          } catch let error {
            print("*** Error generating thumbnail: \(error.localizedDescription)")
          }
          // 画面に表示
          DispatchQueue.main.async {
            self?.pathLabel.text = "\(self?.videoIdentifier ?? "") \n\n \(url.absoluteString)"
            self?.imageView.image = self?.thumbnail
          }
        }
      }
    }
  }
}

extension ViewController: PHPickerViewControllerDelegate {
  // PHPickerViewControllerで動画を選択した時に呼ばれる
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    dismiss(animated: true)
    
    let itemProviders = results.map(\.itemProvider)
    if (itemProviders.count == 0) {
      return
    }
    currentItemProvider = itemProviders[0]
    // 選択した動画のidentifier
    let identifiers = results.compactMap(\.assetIdentifier)
    print("identifiers= \(identifiers)")
    videoIdentifier = identifiers[0]
    displayThumbnail()
  }
}
