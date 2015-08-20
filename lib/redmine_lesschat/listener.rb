require 'rest-client'

class LesschatListener < Redmine::Hook::Listener
	def controller_issues_new_after_save(context={})
		issue = context[:issue]

		url = url_for_project issue.project

		return unless url

		msg = "[#{escape issue.project}] #{escape issue.author} 创建了Issue"

		attachment = {}
		attachment[:fallback] = "#{escape issue.author} 在 #{escape issue.project} 创建了新Issue"
		attachment[:title] = "#{escape issue}"
		attachment[:title_link] = "#{object_url issue}"
		attachment[:color] = '#D26900'
		attachment[:pretext] = msg
		attachment[:text] = escape issue.description if issue.description
		attachment[:fields] = [{
			:title => I18n.t("field_status"),
			:value => escape(issue.status.to_s),
			:short => true
		}, {
			:title => I18n.t("field_priority"),
			:value => escape(issue.priority.to_s),
			:short => true
		}]

		# attachment[:fields] << {
		# 	:title => I18n.t("field_watcher"),
		# 	:value => escape(issue.watcher_users.join(', ')),
		# 	:short => true
		# } if Setting.plugin_redmine_slack[:display_watchers] == 'yes'

		speak attachment, url
	end

	def controller_issues_edit_after_save(context={})
		issue = context[:issue]
		journal = context[:journal]

		url = url_for_project issue.project

		return unless url
		# and Setting.plugin_redmine_slack[:post_updates] == '1'

		msg = "[#{escape issue.project}] #{escape journal.user.to_s} 更新了Issue"

		attachment = {}
		attachment[:fallback] = "#{escape journal.user.to_s} 更新了 #{escape issue.project} 的Issue"
		attachment[:color] = "#E45203"
		attachment[:title] = "#{escape issue}"
		attachment[:title_link] = "#{object_url issue}"
		attachment[:pretext] = msg
		attachment[:text] = escape journal.notes if journal.notes
		attachment[:fields] = journal.details.map { |d| detail_to_field d }

		speak attachment, url
	end

	def model_changeset_scan_commit_for_issue_ids_pre_issue_update(context={})
		issue = context[:issue]
		journal = issue.current_journal
		changeset = context[:changeset]

		url = url_for_project issue.project

		return unless url and issue.save

		msg = "[#{escape issue.project}] #{escape journal.user.to_s} 更新了Issue"

		repository = changeset.repository

		revision_url = Rails.application.routes.url_for(
			:controller => 'repositories',
			:action => 'revision',
			:id => repository.project,
			:repository_id => repository.identifier_param,
			:rev => changeset.revision,
			:host => Setting.host_name,
			:protocol => Setting.protocol
		)

		attachment = {}
		attachment[:pretext] = msg
		attachment[:fallback] = "#{escape journal.user.to_s} 更新了 #{escape issue.project} 的Issue"
		attachment[:color] = "#E45203"
		attachment[:title] = "#{escape issue}"
		attachment[:title_link] = "#{object_url issue}"
		attachment[:text] = ll(Setting.default_language, :text_status_changed_by_changeset, "[#{revision_url}|#{escape changeset.comments}]")
		attachment[:fields] = journal.details.map { |d| detail_to_field d }

		speak attachment, url
	end

	def speak(attachment=nil, url=nil)
		url = Setting.plugin_redmine_lesschat[:webhook_url] if not url rescue nil

		return unless url and attachment

		return unless url.from(0).to(3) == 'http'

		params = {
			:attachment => attachment
		}

		RestClient.post url, params.to_json, :content_type => :json, :accept => :json rescue nil
	end

private
	def escape(msg)
		msg.to_s.gsub("&", "&amp;").gsub("<", "&lt;").gsub(">", "&gt;")
	end

	def object_url(obj)
		Rails.application.routes.url_for(obj.event_url({:host => Setting.host_name, :protocol => Setting.protocol}))
	end

	def url_for_project(proj)
		return nil if proj.blank?

		cf = ProjectCustomField.find_by_name("Lesschat Webhook URL")

		return [
			(proj.custom_value_for(cf).value rescue nil),
			(url_for_project proj.parent),
			Setting.plugin_redmine_lesschat[:webhook_url],
		].find{|v| v.present?}
	end

	# def channel_for_project(proj)
	# 	return nil if proj.blank?

	# 	cf = ProjectCustomField.find_by_name("Slack Channel")

	# 	val = [
	# 		(proj.custom_value_for(cf).value rescue nil),
	# 		(channel_for_project proj.parent),
	# 		Setting.plugin_redmine_slack[:channel],
	# 	].find{|v| v.present?}

	# 	if val.to_s.starts_with? '#'
	# 		val
	# 	else
	# 		nil
	# 	end
	# end

	def detail_to_field(detail)
		if detail.property == "cf"
			key = CustomField.find(detail.prop_key).name rescue nil
			title = key
		elsif detail.property == "attachment"
			key = "attachment"
			title = I18n.t :label_attachment
		else
			key = detail.prop_key.to_s.sub("_id", "")
			title = I18n.t "field_#{key}"
		end

		short = true
		value = escape detail.value.to_s

		case key
		when "title", "subject", "description"
			short = false
		when "tracker"
			tracker = Tracker.find(detail.value) rescue nil
			value = escape tracker.to_s
		when "project"
			project = Project.find(detail.value) rescue nil
			value = escape project.to_s
		when "status"
			status = IssueStatus.find(detail.value) rescue nil
			value = escape status.to_s
		when "priority"
			priority = IssuePriority.find(detail.value) rescue nil
			value = escape priority.to_s
		when "category"
			category = IssueCategory.find(detail.value) rescue nil
			value = escape category.to_s
		when "assigned_to"
			user = User.find(detail.value) rescue nil
			value = escape user.to_s
		when "fixed_version"
			version = Version.find(detail.value) rescue nil
			value = escape version.to_s
		when "attachment"
			attachment = Attachment.find(detail.prop_key) rescue nil
			value = "[#{object_url attachment}|#{escape attachment.filename}]" if attachment
		when "parent"
			issue = Issue.find(detail.value) rescue nil
			value = "[#{object_url issue}|#{escape issue}]" if issue
		end

		value = "-" if value.empty?

		result = { :title => title, :value => value }
		result[:short] = true if short
		result
	end

	def mentions text
		names = extract_usernames text
		names.present? ? "\nTo: " + names.join(', ') : nil
	end

	def extract_usernames text = ''
		# slack usernames may only contain lowercase letters, numbers,
		# dashes and underscores and must start with a letter or number.
		text.scan(/@[a-z0-9][a-z0-9_\-]*/).uniq
	end
end
