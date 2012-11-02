task :default => []

desc "Run unit tests"
task :test do
	system %Q(osascript -e 'tell app "iPhone Simulator" to quit')
	raise "Specs failed." unless system %Q(xcodebuild -workspace stackmob-ios-sdk.xcworkspace -scheme "unit tests" -sdk iphonesimulator -configuration Release build)
end

namespace "test" do
	desc "Run integration tests"
	task :integration do
		system %Q(osascript -e 'tell app "iPhone Simulator" to quit')
		raise "Specs failed." unless system %Q(xcodebuild -workspace stackmob-ios-sdk.xcworkspace -scheme "integration tests" -sdk iphonesimulator -configuration Release build)
	end
	desc "Run Core Data integration tests"
	task :coredata do
		system %Q(osascript -e 'tell app "iPhone Simulator" to quit')
		raise "Specs failed." unless system %Q(xcodebuild -workspace stackmob-ios-sdk.xcworkspace -scheme "integrationTestsCoreData" -sdk iphonesimulator -configuration Release build)
	end
end

task :clean do
  exec "xcodebuild -alltargets clean"
  exec "rm -rf ~/Library/Application\ Support/iPhone\ Simulator/*"
  exec "rm -rf ~/Library/Developer/Xcode/DerivedData/stackmob-ios-sdk*"
  exec "rm -rf ~/Library/Caches/appCode10/DerivedData/stackmob-ios-sdk*"
end