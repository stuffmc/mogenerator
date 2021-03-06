#edit the following paths for the -m -H -M (or -O) and -template-path. Leave -R as . since the rails app is created first here"
run "rm README"
run "rm public/index.html"

#gem 'nifty-generators', :lib => 'nifty-generators', :source => 'http://gems.github.com'
rake "gems:install"

generate :nifty_layout

# ====================================================================================================================================================================
# = You might want to have here a list of the different projects/folders from which you'll run this and comment/uncomment the correct one before running rails -m.
# = Please remember that that the "mogenerator" command, just like any command in this template will be called from within RAILS_ROOT! 
# = It's important to have the paths relatives to this (so first starting with ../) or absolute. 
# = Only exception: -R in this case works well with just "." since it's the current directory :-)
# ====================================================================================================================================================================

#run "mogenerator  -m '../zsiphone/SK.xcdatamodeld/SK 5.xcdatamodel' -H ../zsiphone/Models/Human -M ../zsiphone/Models/Machine -template-path '/Volumes/Macintosh HD/Code/Open Source/mogenerator/contributed templates/StuFF mc' -R ."
run "mogenerator  -m ../7siphone/7S.xcdatamodel -H ../7siphone/Models/Human -M ../7siphone/Models/Machine -template-path '/Volumes/Macintosh HD/Code/Open Source/mogenerator/contributed templates/StuFF mc' -R ."

rake "db:migrate"


plugin "paperclip", :git => "git://github.com/thoughtbot/paperclip.git" if yes?("Install paperclip?")
if yes?("Install restful_authentication?")
  plugin "restful_authentication", :git => "git://github.com/technoweenie/restful_authentication.git"
  generate :authenticated user sessions --include-activation -s
end
                    
git :init

file ".gitignore", <<-END
.DS_Store
log/*.log
tmp/**/*
db/*.sqlite3
END

file "/app/helpers/application_helper.rb", <<-END
# Methods added to this helper will be available to all templates in the application.
module ApplicationHelper
	def partial_button(caption)
		content_for(:button) { caption } 
	end
end
END

git :add => ".", :commit => "-m 'Initial commit of the app created with motemplate.rb (using mo_rails_generator)'"
#run "script/server"