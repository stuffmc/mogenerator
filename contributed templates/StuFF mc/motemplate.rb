#edit the following paths for the -m -H -M (or -O) and -template-path. Leave -R as . since the rails app is created first here"
run "rm README"
run "rm public/index.html"

#gem 'nifty-generators', :lib => 'nifty-generators', :source => 'http://gems.github.com'
rake "gems:install"

generate :nifty_layout

run "mogenerator  -m '../iPhone/SK.xcdatamodeld/SK 5.xcdatamodel' -H ../iPhone/Models/Human -M ../iPhone/Models/Machine -template-path '/Volumes/Macintosh HD/Code/Open Source/mogenerator/contributed templates/StuFF mc' -R ."

rake "db:migrate"

plugin "paperclip", :git => "git://github.com/thoughtbot/paperclip.git"
                    
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