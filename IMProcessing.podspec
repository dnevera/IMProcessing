Pod::Spec.new do |s|

  s.name         = 'IMProcessing'
  s.version      = '0.5.4'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'denn nevera' => 'denn.nevera@gmail.com' }
  s.homepage     = 'http://degradr.photo'
  s.summary      = 'IMProcessing is an image processing framework based on Apple Metal'
  s.description  = 'IMProcessing is an image processing framework provides original effect image/photo. It can be called "masterwork" image processing.'

  s.source       = { :git => 'https://bitbucket.org/degrader/improcessing.git', :tag => '0.5.4'}

  s.osx.deployment_target = "10.11"
  s.ios.deployment_target = "8.0"
  
  s.source_files        = 'IMProcessing/Classes/**/*.{h,swift,m}', 'IMProcessing/Classes/*.{swift}', 'vendor/libjpeg-turbo/include/*'
  s.public_header_files = 'IMProcessing/Classes/**/*.h','IMProcessing/Classes/Shaders/*.h'
  s.vendored_libraries  = 'vendor/libjpeg-turbo/lib/libturbojpeg.a'

  s.frameworks   = 'Metal'
  #
  # does not work with cocoapods 1.0.0rc2
  #
  #s.xcconfig     =   { 'MTL_HEADER_SEARCH_PATHS' => '$(PODS_ROOT)/Headers/Private/IMProcessing', 'HEADER_SEARCH_PATHS' => '$(PODS_ROOT)/Headers/Private/IMProcessing'}
  #
  # TODO: find solution for -OSX/-IOS enviroment variable, at the moment i don;t know what hould it be, so use paths to boths platform
  # MTL shaders has platform independent sources
  #
  s.xcconfig     =   { 'MTL_HEADER_SEARCH_PATHS' => '$(TARGET_BUILD_DIR)/IMProcessing/IMProcessing.framework/Headers $(TARGET_BUILD_DIR)/IMProcessing-OSX/IMProcessing.framework/Headers $(TARGET_BUILD_DIR)/IMProcessing-IOS/IMProcessing.framework/Headers'}

  s.requires_arc = true

end