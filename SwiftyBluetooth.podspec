Pod::Spec.new do |s|
  s.name         = 'SwiftyBluetooth'
  s.version      = '1.0.0'
  s.license      =  'MIT'
  s.homepage     = 'https://github.com/jordanebelanger/SwiftyBluetooth'
  s.authors      = { 'Jordane Belanger' => 'jordane.belanger@gmail.com' }
  s.summary      = 'Fully featured closures based library for CoreBluetooth'
  s.source       = { :git => 'https://github.com/jordanebelanger/SwiftyBluetooth.git', :tag => s.version }
  s.source_files = 'SwiftyBluetooth/Source/*.swift'
  s.requires_arc = true
  s.ios.deployment_target = '9.0'
end
