Pod::Spec.new do |s|
  s.name         = 'SwiftyBluetooth'
  s.version      = '0.1.0'
  s.license      =  { :type => 'MIT' }
  s.homepage     = 'https://github.com/tehjord/SwiftyBluetooth'
  s.authors      = { 'Jordan Belanger' => 'jordane.belanger@gmail.com' }
  s.summary      = '100% Swift and full featured closures based Bluetooth library'
  s.source       = { :git => 'https://github.com/tehjord/SwiftyBluetooth.git', :tag => s.version.to_s }
  s.source_files = 'SwiftyBluetooth/Source/*.swift'
  s.requires_arc = true
  s.ios.deployment_target = '9.0'
end