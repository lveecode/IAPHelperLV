#
# Be sure to run `pod lib lint IAPHelperLV.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
    
    s.swift_version = '5.0'
    
    s.name             = 'IAPHelperLV'
    s.version          = '0.1.1'
    s.summary          = 'In-app purchase block-based helper'
    
    # This description is used to generate tags and improve search results.
    #   * Think: What does it do? Why did you write it? What is the focus?
    #   * Try to keep it short, snappy and to the point.
    #   * Write the description between the DESC delimiters below.
    #   * Finally, don't worry about the indent, CocoaPods strips it!
    
    s.description      = <<-DESC
    In-app purchase block-based helper
    DESC
    
    s.homepage         = 'https://github.com/LVeecode/IAPHelperLV'
    # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
    s.license          = { :type => 'MIT', :file => 'LICENSE' }
    s.author           = { 'LVeecode' => 'lveecode@gmail.com' }
    s.source           = { :git => 'https://github.com/LVeecode/IAPHelperLV.git', :tag => s.version.to_s }
    # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'
    
    s.ios.deployment_target = '11.0'
    
    s.source_files = 'IAPHelperLV/Classes/**/*'
    
    # s.resource_bundles = {
    #   'IAPHelperLV' => ['IAPHelperLV/Assets/*.png']
    # }
    
    # s.public_header_files = 'Pod/Classes/**/*.h'
    # s.frameworks = 'UIKit', 'MapKit'
    # s.dependency 'AFNetworking', '~> 2.3'
end
