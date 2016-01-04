Pod::Spec.new do |s|

  s.name         = 'IMProcessing'
  s.version      = '0.2.0'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'denn nevera' => 'denn.nevera@gmail.com' }
  s.homepage     = 'http://degradr.photo'
  s.summary      = 'IMProcessing is an image processing framework based on Apple Metal'
  s.description  = 'IMProcessing is an image processing framework provides original effect image/photo. It can be called "masterwork" image processing.'

  s.source       = { :git => 'https://bitbucket.org/degrader/improcessing.git', :tag => '0.2.0'}

  s.osx.deployment_target = "10.11"
  s.ios.deployment_target = "8.3"
  
  s.source_files        = 'IMProcessing/Classes/**/*.{h,swift,m}', 'IMProcessing/Classes/*.{swift}', 'vendor/libjpeg-turbo/include/*'
  s.public_header_files = 'IMProcessing/Classes/**/*.h','IMProcessing/Classes/Shaders/*.h'
  s.vendored_libraries  = 'vendor/libjpeg-turbo/lib/libturbojpeg.a'

  s.frameworks   = 'Metal'
  s.xcconfig     =   { 'OTHER_LDFLAGS' => '/opt/libjpeg-turbo/lib/libturbojpeg.a'}

 #s.libraries = 'turbojpeg'
 #s.xcconfig  =   { 'LIBRARY_SEARCH_PATHS' =>  '/opt/libjpeg-turbo/lib'}

  s.requires_arc = true

end