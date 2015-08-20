require 'redmine'

require_dependency 'redmine_lesschat/listener'

Redmine::Plugin.register :redmine_lesschat do
	name 'Redmine Lesschat'
	author 'YC Tech Beijing'
	url 'https://github.com/lesschat/redmine_lesschat'
	author_url 'https://www.lesschat.com'
	description 'Lesschat integration'
	version '0.1'

	requires_redmine :version_or_higher => '0.8.0'

	settings :default => {'webhook_url' => ''}, :partial => 'settings/lesschat_settings'
end
