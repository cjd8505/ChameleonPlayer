Pod::Spec.new do |s|
  s.name     = 'ChameleonPlayer'
  s.version  = '3.0.0'
  s.author   = { 'Eyepetizer Inc.' => 'liuyan@kaiyanapp.com' }
  s.homepage = 'https://gitlab.com/eyepetizer/Eye-iOS/ChameleonPlayer'
  s.summary  = 'ChameleonPlayer is a VR Video Player for iOS. Include 360 degress and VR Glasses Mode.'
  s.source   = { :git => 'https://gitlab.com/eyepetizer/Eye-iOS/ChameleonPlayer.git', :tag => '3.0.0' }
  s.license  = 'MIT'
  
  s.platform = :ios
  s.source_files = 'Source/*.swift'
  s.requires_arc = true
  s.frameworks   = 'SpriteKit', 'AVFoundation', 'SceneKit'
end
