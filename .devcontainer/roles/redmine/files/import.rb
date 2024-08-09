#!/usr/bin/env ruby

require 'yaml'
require 'fileutils'

User.current = User.find(1)

class Import
  TMP_DIR = File.join(Rails.root, 'tmp')

  ALLOW_FIELD_FORMTS = [
    'string',
    'text',
    'link',
    'date',
    'list',
    'int',
    'float',
    'bool',
    'version',
    'user',
    'attachment',
    'enumeration'
  ].map(&:freeze).freeze

  ## システム管理者情報の更新
  def admin
    data_file = File.join(TMP_DIR, 'admin.yml')
    data = load_data data_file
    if data.present?
      puts "\nImport admin\n-----------------------"
      User.update!(1, data)
      puts User.find_by_id(1)
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## ステータスのインポート
  def status
    data_file = File.join(TMP_DIR, 'status.yml')
    statuses = load_data data_file
    if statuses.present?
      puts "\nImport status\n-----------------------"
      statuses.each do |data|
        if data['id'].present?
          status = IssueStatus.find_by_id(data['id'])
          status.name = data['name']
        else
          status = IssueStatus.find_by_name(data['name'])
        end
        status ||= IssueStatus.new
        status.safe_attributes = data
        status.position = data['position'] if data['position'].present?
        status.save!
        puts status
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## トラッカーのインポート
  def tracker
    data_file = File.join(TMP_DIR, 'tracker.yml')
    trackers = load_data data_file
    if trackers.present?
      puts "\nImport tracker\n-----------------------"
      default_issue_status = IssueStatus.first
      # ワークフローのコピー元の指定がないトラッカーから先に登録
      import_trackers = trackers.reject {|item| item['copy_workflow_from'].present? }
      import_trackers.concat trackers.select {|item| item['copy_workflow_from'].present? }
      import_trackers.each do |data|
        if data['id'].present?
          tracker = Tracker.find_by_id(data['id'])
          tracker.name = data['name']
        else
          tracker = Tracker.find_by_name(data['name'])
        end
        unless tracker
          tracker = Tracker.new
          tracker.name = data['name']
          tracker.core_fields = [
            'assigned_to_id',
            'category_id',
            'fixed_version_id',
            'parent_issue_id',
            'start_date',
            'due_date',
            'estimated_hours',
            'done_ratio',
            'description'
          ]
        end
        tracker.core_fields = data['enabled_standard_fields'] if data['enabled_standard_fields'].present?
        tracker.description = data['description'] if data.key?('description')
        tracker.default_status_id = default_issue_status.id
        tracker.is_in_roadmap = !!data['is_in_roadmap'] if data.key?('is_in_roadmap')
        if data['default_status'].present?
          if data['default_status'].is_a?(Hash)
            if data['default_status'].key?('id') && data['default_status'].id
              issue_status = IssueStatus.find_by_id(data['default_status'].id)
            else
              issue_status = IssueStatus.find_by_name(data['default_status'].name)
            end
          else
            issue_status = IssueStatus.find_by_name(data['default_status'])
          end
          tracker.default_status_id = issue_status.id
        end
        tracker.position = data['position'] if data['position'].present?
        tracker.save!
        if data['copy_workflow_from'].present?
          copy_from = Tracker.find_by_name(data['copy_workflow_from'])
          tracker.copy_workflow_rules(copy_from) if copy_from
        end
        puts tracker
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## ロールのインポート
  def role
    data_file = File.join(TMP_DIR, 'role.yml')
    roles = load_data data_file
    if roles.present?
      puts "\nImport role\n-----------------------"
      roles.each do |data|
        if data['id'].present?
          role = Role.find_by_id(data['id'])
          role.name = data['name']
        else
          role = Role.find_by_name(data['name'])
        end
        is_new = false
        unless role
          is_new = true
          role = Role.new
          role.name = data['name']
          role.assignable = true
          role.issues_visibility = 'default'
          role.users_visibility = 'all'
          role.time_entries_visibility = 'all'
        end
        # このロールにチケットを割り当て可能
        role.assignable = data['assignable'] if data.key?('assignable')
        # 表示できるチケット
        role.issues_visibility = data['issues_visibility'] if data.key?('assignable')
        # 表示できるユーザー
        role.users_visibility = data['users_visibility'] if data.key?('assignable')
        # 表示できる作業時間
        if data.key?('time_entries_visibility')
          role.time_entries_visibility = data['time_entries_visibility']
        end
        # 権限
        role.permissions = data['permissions'].map(&:to_sym) if data.key?('permissions')
        # 権限(追加)
        if data.key?('append_permissions')
          role.permissions.concat data['append_permissions'].map(&:to_sym)
        end
        # メンバーの管理
        role.all_roles_managed = '1'
        role.managed_role_ids = []
        if data.key?('managed_roles') && data['permissions'].include?('manage_members')
          role.all_roles_managed = '0'
          role.managed_role_ids = Role.where(name: data['managed_roles']).pluck(:id)
        end

        permissions_all_trackers = {
          'view_issues' => '1',
          'add_issues' => '1',
          'edit_issues' => '1',
          'add_issue_notes' => '1',
          'delete_issues' => '1'
        }
        permissions_tracker_ids = {
          'view_issues' => [],
          'add_issues' => [],
          'edit_issues' => [],
          'add_issue_notes' => [],
          'delete_issues' => []
        }
        if data.key?('permissions_trackers')
          permissions_trackers = data['permissions_trackers']
          if permissions_trackers.key?('view_issues')
            view_issue_tracker_ids = Tracker.where(name: permissions_trackers['view_issues']).pluck(:id)
            permissions_tracker_ids['view_issues'] = view_issue_tracker_ids.map {|data| item.to_s }
            permissions_all_trackers['view_issues'] = '0'
          end
          if permissions_trackers.key?('add_issues')
            add_issue_tracker_ids = Tracker.where(name: permissions_trackers['add_issues']).pluck(:id)
            permissions_tracker_ids['add_issues'] = add_issue_tracker_ids.map {|data| item.to_s }
            permissions_all_trackers['add_issues'] = '0'
          end
          if permissions_trackers.key?('edit_issues')
            edit_issue_tracker_ids = Tracker.where(name: permissions_trackers['edit_issues']).pluck(:id)
            permissions_tracker_ids['edit_issues'] = edit_issue_tracker_ids.map {|data| item.to_s }
            permissions_all_trackers['edit_issues'] = '0'
          end
          if permissions_trackers.key?('add_issue_notes')
            add_issue_note_tracker_ids = Tracker.where(name: permissions_trackers['add_issue_notes']).pluck(:id)
            permissions_tracker_ids['add_issue_notes'] = add_issue_note_tracker_ids.map {|data| item.to_s }
            permissions_all_trackers['add_issue_notes'] = '0'
          end
          if permissions_trackers.key?('delete_issues')
            delete_issue_tracker_ids = Tracker.where(name: permissions_trackers['delete_issues']).pluck(:id)
            permissions_tracker_ids['delete_issues'] = delete_issue_tracker_ids.map {|data| item.to_s }
            permissions_all_trackers['delete_issues'] = '0'
          end
        end
        role.permissions_all_trackers = permissions_all_trackers
        role.permissions_tracker_ids = permissions_tracker_ids
        # 並び順
        role.position = data['position'] if data.key?('position')
        role.save!
        # 新規登録時のみワークフローのコピーを実行
        if is_new && data.key?('copy_workflow_from')
          copy_from = Role.find_by_name(data['copy_workflow_from'])
          role.copy_workflow_rules(copy_from) if copy_from
        end
        puts role
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## チケットの優先度のインポート
  def priority
    data_file = File.join(TMP_DIR, 'priority.yml')
    priorities = load_data data_file
    if priorities.present?
      puts "\nImport priority\n-----------------------"
      priorities.each do |data|
        if data['id'].present?
          priority = IssuePriority.find_by_id(data['id'])
        else
          priority = IssuePriority.find_by_name(data['name'])
        end
        priority ||= IssuePriority.new({active: ture})
        import_enumeration priority, data
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## 文書カテゴリのインポート
  def document_category
    data_file = File.join(TMP_DIR, 'document_category.yml')
    document_categories = load_data data_file
    if document_categories.present?
      puts "\nImport document category\n-----------------------"
      document_categories.each do |data|
        if data['id'].present?
          document_category = DocumentCategory.find_by_id(data['id'])
        else
          document_category = DocumentCategory.find_by_name(data['name'])
        end
        document_category ||= DocumentCategory.new({active: true})
        import_enumeration document_category, data
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## 作業分類のインポート
  def time_entry_activity
    data_file = File.join(TMP_DIR, 'time_entry_activity.yml')
    time_entry_activities = load_data data_file
    if time_entry_activities.present?
      puts "\nImport time entry activity\n-----------------------"
      time_entry_activities.each do |data|
        if data['id'].present?
          time_entry_activity = TimeEntryActivity.find_by_id(data['id'])
        else
          time_entry_activity = TimeEntryActivity.find_by_name(data['name'])
        end
        time_entry_activity ||= TimeEntryActivity.new({active: true})
        import_enumeration time_entry_activity, data
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## チケットカスタムフィールドのインポート
  def issue_custom_field
    data_file = File.join(TMP_DIR, 'issue_custom_field.yml')
    custom_fields = load_data data_file
    if custom_fields.present?
      puts "\nImport issue custom field\n-----------------------"
      custom_fields.each do |data|
        next unless ALLOW_FIELD_FORMTS.include?(data['field_format'])

        cf = IssueCustomField.find_by_name(data['name'])
        cf ||= IssueCustomField.new({name: data['name']})
        import_custom_field cf, data
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_DEBUG']
  end

  ## プロジェクトカスタムフィールドのインポート
  def project_custom_field
    data_file = File.join(TMP_DIR, 'project_custom_field.yml')
    custom_fields = load_data data_file
    if custom_fields.present?
      puts "\nImport project custom field\n-----------------------"
      custom_fields.each do |data|
        next unless ALLOW_FIELD_FORMTS.include?(data['field_format'])

        cf = ProjectCustomField.find_by_name(data['name'])
        cf ||= ProjectCustomField.new({name: data['name']})
        import_custom_field cf, data
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## ユーザーカスタムフィールドのインポート
  def user_custom_field
    data_file = File.join(TMP_DIR, 'user_custom_field.yml')
    custom_fields = load_data data_file
    if custom_fields.present?
      puts "\nImport user custom field\n-----------------------"
      custom_fields.each do |data|
        next unless ALLOW_FIELD_FORMTS.include?(data['field_format'])

        cf = UserCustomField.find_by_name(data['name'])
        cf ||= UserCustomField.new({name: data['name']})
        import_custom_field cf, data
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## 設定のインポート
  def setting
    data_file = File.join(TMP_DIR, 'setting.yml')
    redmine_setting = load_data data_file
    if redmine_setting.present?
      puts "\nImport setting\n-----------------------"
      ## Redmine本体の設定をインポート
      core_setting = redmine_setting.reject { |key, value| key.start_with?('plugin_') }
      if core_setting.key?('default_projects_trackers')
        core_setting['default_projects_tracker_ids'] = Tracker.where(name: core_setting['default_projects_trackers']).pluck(:id).map { |item| item.to_s }
        core_setting.delete('default_projects_trackers')
      end
      if core_setting.present?
        Setting.set_all_from_params(core_setting)
        puts "\n### Core setting\n"
        puts core_setting
      end
      ## プラグインの設定をインポート
      plugin_setting = redmine_setting.select {|key, value| key.start_with?('plugin_') }
      puts plugin_setting
      if plugin_setting.present?
        plugin_setting.each do |key, value|
          if Redmine::Plugin.installed? key.sub('plugin_', '').to_s
            Setting.send(key + '=', value.with_indifferent_access)
          end
        end
        puts "\n### Plugin setting\n"
        puts plugin_setting
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## ワークフローのインポート
  def workflow
    data_file = File.join(TMP_DIR, 'workflow.yml')
    workflows = load_data data_file
    if workflows.present?
      puts "\nImport workflow\n-----------------------"
      all_statuses = IssueStatus.all
      workflows.each do |data|
        roles = Role.where(:name =>  data['roles']).to_a
        trackers = Tracker.where(:name =>  data['trackers']).to_a

        transitions = {}
        status_ids = all_statuses.pluck(:id).map { |item| item.to_s }
        status_ids.prepend '0'
        status_ids.each do |status_id|
          all_statuses.each do |status|
            transitions[status_id] = {} unless transitions.key?(status_id)
            transitions[status_id][status.id.to_s] = {'always' => false, 'author' => false, 'assignee' => false}
          end
        end
        data['transitions'].each do |transition|
          from_status_id = '0'
          if transition['from']
            from_status = IssueStatus.find_by_name(transition['from'])
            from_status_id = from_status.id.to_s
          end
          to_statuses = IssueStatus.where(:name => transition['to'])
          to_statuses.each do |to_status|
            to_status_id = to_status.id.to_s
            transitions[from_status_id][to_status_id]['always'] = true
          end
        end
        WorkflowTransition.replace_transitions(trackers, roles, transitions)
        puts({'tracker' => trackers.pluck(:name), 'role' => roles.pluck(:name), 'transition' => transitions})
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## フィールド権限のインポート
  def workflow_permission
    data_file = File.join(TMP_DIR, 'workflow_permission.yml')
    workflow_permissions = load_data data_file
    if workflow_permissions.present?
      puts "\nImport workflow permission\n-----------------------"
      all_statuses = IssueStatus.all
      status_ids = all_statuses.pluck(:id).map { |item| item.to_s }
      permission_fields = {
        'project' => {
          'name' => 'project_id',
          'values' =>['readonly']
        },
        'tracker' => {
          'name' => 'tracker_id',
          'values' =>['readonly']
        },
        'subject' => {
          'values' => ['readonly']
        },
        'description' => {
          'values' => ['readonly', 'required']
        },
        'priority' => {
          'name' => 'priority_id',
          'values' => ['readonly']
        },
        'assigned_to' => {
          'name' => 'assigned_to_id',
          'values' => ['readonly', 'required']
        },
        'category' => {
          'name' => 'category_id',
          'values' => ['readonly', 'required']
        },
        'fixed_version' => {
          'name' =>'fixed_version_id',
          'values' => ['readonly', 'required']
        },
        'parent_issue' => {
          'name' => 'parent_issue_id',
          'values' => ['readonly', 'required']
        },
        'start_date' => {
          'values' => ['readonly', 'required']
        },
        'due_date' => {
          'values' => ['readonly', 'required']
        },
        'estimated_hours' => {
          'values' => ['readonly', 'required']
        },
        'done_ratio' => {
          'values' => ['readonly', 'required']
        },
        'is_private' => {
          'values' => ['readonly', 'required']
        }
      }
      workflow_permissions.each do |data|
        roles = Role.where(:name => data['roles'])
        trackers = Tracker.where(:name => data['trackers'])
        permissions = {}
        status_ids.each do |status_id|
          permissions[status_id] = {} unless permissions.key?(status_id)
          permission_fields.each do |key, value|
            field_name = value['name'] || key
            permissions[status_id][field_name] = 'no_change'
          end
        end
        core_fields = permission_fields.keys
        data['permissions'].each do |setting|
          update_fields = setting['fields']
          update_fields = [update_fields] unless update_fields.is_a?(Array)
          custom_field_names = update_fields.reject {|field| core_fields.include?(field) }
          if custom_field_names.present?
            custom_fields = IssueCustomField.where(:name => custom_field_names)
          end
          update_status_ids = IssueStatus.where(:name => setting['statuses']).pluck(:id).map { |item| item.to_s }
          update_status_ids.each do |update_status_id|
            update_fields.each do |update_field|
              field_name = update_field
              if permission_fields.key?(field_name)
                field_name = permission_fields[field_name]['name'] if permission_fields[field_name].key?('name')
                permissions[update_status_id][field_name] = setting['permission']
              end
              if custom_fields.present?
                custom_fields.each do |cf|
                  permissions[update_status_id][cf.id] = setting['permission']
                end
              end
            end
          end
        end
        permissions.each_value do |rule_by_status_id|
          rule_by_status_id.reject! {|status_id, rule| rule == 'no_change'}
        end
        WorkflowPermission.replace_permissions(trackers, roles, permissions)
        puts({'tracker' => trackers.pluck(:name), 'role' => roles.pluck(:name), 'permission' => permissions})
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## ユーザーのインポート
  def user
    data_file = File.join(TMP_DIR, 'user.yml')
    users = load_data data_file
    if users.present?
      puts "\nImport user\n-----------------------"
      # メール通知の設定値一覧
      allow_mail_notification_values = [
        # 参加しているプロジェクトのすべての通知
        'selected',
        # ウォッチ中または自分が関係しているもの
        'only_my_events',
        # ウォッチ中または自分が担当しているもの
        'only_assigned',
        # ウォッチ中または自分が作成したもの
        'only_owner',
        # 通知しない
        'none'
      ]
      # コメントの表示順の設定値一覧
      allow_comments_sorting_values = [
        # 古い順
        'asc',
        # 新しい順
        'desc'
      ]
      # テキストエリアのフォントの設定値一覧
      allow_textarea_font_values = [
        # 等幅
        'monospace',
        # プロポーショナル
        'proportional'
      ]
      users.each do |data|
        next unless data.key?('login')

        user = User.find_by_login(data['login'])
        if user
          next if user.id == 1

          # 既存ユーザー情報の更新
          user.firstname = data['firstname'] if data.key?('firstname')
          user.lastname = data['lastname'] if data.key?('lastname')
          user.mail = data['mail'] if data.key?('mail')
          if data.key?('password') && data['password'].present?
            user.password = data['password']
            user.password_confirmation = data['password']
          end
        else
          # ユーザーの新規登録
          user = User.new(:language => Setting.default_language, :mail_notification => Setting.default_notification_option)
          user.login = data['login']
          # 名
          user.firstname = data['firstname']
          # 姓
          user.lastname = data['lastname']
          # メールアドレス
          user.mail = data['mail']
          user.generate_password = true
          if data.key?('password') && data['password'].present?
            user.password = data['password']
            user.password_confirmation = data['password']
            user.generate_password = false
          end
        end
        # 言語
        user.language = data['language'] if data.key?('language')
        # システム管理者
        user.admin = !!data['admin'] if data.key?('admin') && user.id != 1
        # 次回ログイン時にパスワード変更を強制
        user.must_change_passwd = !!data['must_change_passwd'] if data.key?('must_change_passwd')
        # メール通知
        if data.key?('mail_notification') && allow_mail_notification_values.include?(data['mail_notification'])
          user.mail_notification = data['mail_notification']
        end
        # UserPreference
        # ------------------
        # 優先度が 高い 以上のチケットについても通知
        user.pref.notify_about_high_priority_issues = !!data['notify_about_high_priority_issues'] if data.key?('notify_about_high_priority_issues')
        # 自分自身による変更の通知は不要
        user.pref.no_self_notified = data['no_self_notified'] if data.key?('no_self_notified')
        # オートウォッチ
        if data.key?('auto_watch_on')
          data['auto_watch_on'] = [] unless data['auto_watch_on']
          user.pref.auto_watch_on = data['auto_watch_on']
        end
        # メールアドレスを隠す
        user.pref.hide_mail = data['hide_mail'] if data.key?('hide_mail')
        # コメントの表示順
        if data.key?('comments_sorting') && allow_comments_sorting_values.include?(data['comments_sorting'])
          user.pref.comments_sorting = data['comments_sorting']
        end
        # データを保存せずにページから移動するときに警告
        user.pref.warn_on_leaving_unsaved = data['warn_on_leaving_unsaved'].to_bool if data.key?('warn_on_leaving_unsaved')
        # テキストエリアのフォント
        if data.key?('textarea_font') && allow_textarea_font_values.include?(data['textarea_font'])
          user.pref.textarea_font = data['textarea_font']
        end
        # カスタムフィールド
        # ------------------
        if data.key?('custom_fields')
          custom_field_values = {}
          data['custom_fields'].each do |custom_field|
            if custom_field['id'].present?
              cf = UserCustomField.find_by_id(custom_field['id'])
            else
              cf = UserCustomField.find_by_name(custom_field['name'])
            end
            custom_field_values[cf.id] = custom_field['value'] if cf
          end
          user.custom_field_values = custom_field_values
        end
        if data.key?('locked')
          user.status = data['locked'] ? User::STATUS_LOCKED : User::STATUS_ACTIVE
        end
        user.save!
        puts user
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## グループのインポート
  def group
    data_file = File.join(TMP_DIR, 'group.yml')
    groups = load_data data_file
    if groups.present?
      puts "\nImport group\n-----------------------"
      groups.each do |data|
        if data['id'].present?
          group = Group.find_by_id(data['id'])
        else
          group = Group.find_by_lastname(data['name'])
        end
        group ||= Group.new
        group.name = data['name']
        group.save!
        if data['users'].present?
          users = User.where(login: data['users']).to_a
          group.users = users
        end
        puts group
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## チケットのカスタムクエリーのインポート
  def issue_query
    data_file = File.join(TMP_DIR, 'issue_query.yml')
    custom_queries = load_data data_file
    if custom_queries.present?
      puts "\nImport issue query\n-----------------------"
      custom_queries.each do |data|
        project = nil
        if data['project']
          project = Project.find_by_identifier(data['project'])
          project ||= Project.find_by_name(data['project'])
        end
        import_issue_query data, project, true
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## プロジェクトのカスタムクエリーのインポート
  def project_query
    data_file = File.join(TMP_DIR, 'project_query.yml')
    project_queries = load_data data_file
    if project_queries.present?
      puts "\nImport project query\n-----------------------"
      project_queries.each do |data|
        if data['id'].present?
          project_query = ProjectQuery.find_by_id(data['id'])
        else
          project_query = ProjectQuery.find_by_name(data['name'])
        end
        unless project_query
          project_query = ProjectQuery.new({name: data['name']})
          project_query.visibility = 1
          project_query.user = User.current
        end
        project_query.name = data['name']
        project_query.project = nil
        ## フィルター
        filter_fields = []
        filter_operators = {}
        filter_values = {}
        data['filters'].each do |key, value|
          field_name = key
          field_filter_operator = value['operator'] || value['op']
          field_filter_value = value['values'] || []
          case key
          when 'id'
            field_name = 'id'
            field_filter_value = User.where(:login => field_filter_value).pluck(:id).map {|item| item.to_s }
            field_filter_value.push 'mine' if field_filter_value.include?('mine')
            field_filter_value.push 'bookmarks' if field_filter_value.include?('bookmarks')
          end
          filter_fields.push field_name
          filter_operators[field_name] = field_filter_operator
          filter_values[field_name] = field_filter_value
        end
        form_params = {
          :display_type => 'bord',
        }
        ## フィルター
        form_params[:fields] = filter_fields
        form_params[:operators] = filter_operators
        form_params[:values] = filter_values
        ## 説明
        if data.key?('description') && data['description'].present?
          form_params[:description] = data['description']
        end
        ## 表示
        form_params[:visibility] = !!data['visibility'] ? 1 : 0 if data.key?('visibility')
        ## 表示形式
        form_params[:display_type] = data['display_type'] if data.key?('display_type')
        project_query.build_from_params form_params
        ## @todo `Validation failed: Project cannot be blank`が発生
        project_query.save!
        puts project_query.name
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## 作業時間のカスタムクエリーのインポート
  def time_entry_query
    data_file = File.join(TMP_DIR, 'time_entry_query.yml')
    custom_queries = load_data data_file
    if custom_queries.present?
      puts "\nImport time entry query\n-----------------------"
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## プロジェクトのインポート
  def project
    data_file = File.join(TMP_DIR, 'project.yml')
    projects = load_data data_file
    if projects.present?
      puts "\nImport project\n-----------------------"
      projects.each do |identifier, data|
        import_project identifier, data
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## 添付ファイルのインポート
  def attachment
    data_file = File.join(TMP_DIR, 'attachment.yml')
    attachments = load_data data_file
    if attachments.present?
      puts "\nImport attachment\n-----------------------"
      attachments.each do |data|
        project = Project.find_by_identifier(data['project'])
        project ||= Project.find_by_name(data['project'])
        project ||= Project.find_by_id(data['project'])
        if project
          container = project
          if data.key?('wiki')
            wiki = project.wiki.find_or_new_page data['wiki']
            container = wiki
          end
          attachment = Attachment.new(:container => container, :author => User.current)
          attach_file = File.open(data['remote_file'])
          attachment.file = attach_file
          attachment.filename = data['base_file_name']
          attachment.filename = data['file_name'] if data.key?('file_name')
          attachment.description = data['description'] if data.key?('description')
          attachment.save!
          puts attachment
        end
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## メッセージカスタマイズの設定のインポート
  def message_customize
    data_file = File.join(TMP_DIR, 'message_customize.yml')
    if Redmine::Plugin.installed? :redmine_message_customize
      message_customize_setting = load_data data_file
      if message_customize_setting.present?
        puts "\nImport redmine_message_customize setting\n-----------------------"
        lang = ENV['REDMINE_LANG'] || 'ja'
        setting = {}
        setting[lang] = message_customize_setting
        plugin_setting = CustomMessageSetting.find_or_default
        plugin_setting.update_with_custom_messages_yaml(setting)
        puts setting
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## view_customizeの設定のインポート
  def view_customize
    data_file = File.join(TMP_DIR, 'view_customize.yml')
    if Redmine::Plugin.installed? :view_customize
      settings = load_data data_file
      if settings.present?
        puts "\nImport view_customize settings\n-----------------------"
        settings.each do |data|
          if data['id'].present?
            view_customize = ViewCustomize.find_by_id(data['id'])
          else
            view_customize = ViewCustomize.find_by_comments(data['name'])
          end
          view_customize ||= ViewCustomize.new({comments: data['name']})
          view_customize.code = data['code']
          view_customize.path_pattern = data['path_pattern'] if data.key?('path_pattern')
          view_customize.project_pattern = data['project_pattern'] if data.key?('project_pattern')
          view_customize.insertion_position = data['insertion_position'] if data.key?('insertion_position')
          view_customize.customize_type = data['customize_type'] if data.key?('customize_type')
          view_customize.is_enabled = !!data['is_enabled'] ? 1 : 0 if data.key?('is_enabled')
          view_customize.save!
          puts view_customize
        end
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## redmine_issue_templatesのチケットテンプレートのインポート
  def issue_template
    data_file = File.join(TMP_DIR, 'issue_template.yml')
    if Redmine::Plugin.installed? :redmine_issue_templates
      issue_templates = load_data data_file
      if issue_templates.present?
        puts "\nImport issue template settings\n-----------------------"
        issue_templates.each do |data|
          tracker = Tracker.find_by_name(data['tracker'])
          if data['id'].present?
            template = GlobalIssueTemplate.find_by_id(data['id'])
          else
            template = GlobalIssueTemplate.find_by_tracker_id_and_title(tracker.id, data['name'])
          end
          template ||= GlobalIssueTemplate.new
          ## トラッカー
          template.tracker_id = tracker.id
          ## テンプレート名
          template.title = data['name']
          ## チケットタイトル
          template.issue_title = data['issue_title'] if data.key?('issue_title')
          ## チケット本文
          template.description = data['description']
          ## デフォルト値
          template.is_default = !!data['is_default'] if data.key?('is_default')
          ## 有効
          template.enabled = !!data['enabled'] if data.key?('enabled')
          ## メモ
          template.note = data['note'] if data.key?('note')
          ## 関連リンク
          template.related_link = data['related_link'] if data.key?('related_link')
          ## 関連リンクのタイトル
          template.link_title = data['link_title'] if data.key?('link_title')
          ## 表示順序
          template.position = data['position'] if data.key?('position')
          template.author = User.current if template.new_record?
          template.save!
          puts template
        end
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  ## redmine_issue_templatesのコメントテンプレートのインポート
  def note_template
    data_file = File.join(TMP_DIR, 'note_template.yml')
    if Redmine::Plugin.installed? :redmine_issue_templates
      note_templates = load_data data_file
      if note_templates.present?
        puts "\nImport note template settings\n-----------------------"
        note_templates.each do |data|
          tracker = Tracker.find_by_name(data['tracker'])
          if data['id'].present?
            template = GlobalNoteTemplate.find_by_id(data['id'])
          else
            template = GlobalNoteTemplate.find_by_tracker_id_and_name(tracker.id, data['name'])
          end
          template ||= GlobalNoteTemplate.new
          ## トラッカー
          template.tracker_id = tracker.id
          ## テンプレート名
          template.name = data['name']
          ## コメント
          template.description = data['description']
          ## 有効
          template.enabled = !!data['enabled'] if data.key?('enabled')
          ## メモ
          template.memo = data['memo'] if data.key?('memo')
          ## 表示するロール
          if data.key?('roles')
            template.visibility = 1
            template.role_ids = Role.where(:name =>  data['roles']).pluck(:id)
          elsif template.new_record?
            template.visibility = 2
          end
          ## 表示位置
          template.position = data['position'] if data.key?('position')
          template.author = User.current if template.new_record?
          template.save!
          puts template
        end
      end
    end
    FileUtils.rm_f(data_file) unless ENV['IMPORT_AFTER_NO_DELETE_DATA_FILE']
  end

  private

  ## インポートデータのロード
  def load_data(data_file)
    import_data = nil
    if File.exist?(data_file)
      import_data = YAML.load_file(data_file)
    end
    import_data
  end

  ## 選択肢の値のインポート
  def import_enumeration(enumeration, data)
    enumeration.name = data['name']
    enumeration.active = !!data['active'] if data.key?('active')
    enumeration.is_default = !!data['is_default'] if data.key?('is_default')
    enumeration.position = data['position'] if data.key?('position')
    enumeration.save!
    puts enumeration
  end

  ## カスタムフィールドのインポート
  def import_custom_field(cf, data)
    allow_length_formats = ['string', 'text', 'link', 'int', 'float']
    allow_regexp_formats = ['string', 'text', 'link', 'int', 'float']
    allow_default_value_formats = ['string', 'text', 'link', 'int', 'float', 'date', 'bool']
    allow_text_formatting_formats = ['string', 'text']
    allow_url_pattern_formats = ['string', 'link', 'date', 'int', 'float', 'list', 'bool']
    allow_edit_tag_style_formats = ['version', 'user', 'list', 'bool', 'enumeration']
    allow_multiple_formats = ['version', 'user', 'list', 'enumeration']
    allow_searchable_formats = ['string', 'text', 'list']

    # 形式
    cf.field_format = data['field_format']
    # 名称
    cf.name = data['name']
    # 説明
    cf.description = data['description'] if data.key?('description')
    # 必須
    cf.is_required = !!data['is_required'] if data.key?('is_required')
    # 最小値または最小文字列長
    if data.key?('min_length') && allow_length_formats.include?(data['field_format'])
      cf.min_length = data['min_length'].to_s
    end
    # 最大値値または最小文字列長
    if data.key?('max_length') && allow_length_formats.include?(data['field_format'])
      cf.max_length = data['max_length'].to_s
    end
    # 正規表現
    if data.key?('regexp') && allow_regexp_formats.include?(data['field_format'])
      cf.regexp = data['regexp']
    end
    # 初期値
    if data.key?('default_value') && allow_default_value_formats.include?(data['field_format'])
      cf.default_value = data['default_value'].to_s
    end
    # テキスト書式
    if data.key?('text_formatting') && allow_text_formatting_formats.include?(data['field_format'])
      cf.text_formatting = data['text_formatting'] ? true : false
    end
    # 値に設定するリンクURL
    if data.key?('url_pattern') && allow_url_pattern_formats.include?(data['field_format'])
      cf.url_pattern = data['url_pattern']
    end
    # 表示(入力形式)
    if data.key?('edit_tag_style') && allow_edit_tag_style_formats.include?(data['field_format'])
      edit_tag_style = nil
      if ['check_box', 'radio'].include?(data['edit_tag_style'])
        edit_tag_style = data['edit_tag_style']
        cf.edit_tag_style = edit_tag_style
      end
    end
    # 複数選択
    if data.key?('multiple') && allow_multiple_formats.include?(data['field_format'])
      cf.multiple = data['multiple'] ? true : false
    end
    # 検索対象
    if data.key?('searchable') && allow_searchable_formats.include?(data['field_format'])
      cf.searchable = data['searchable'] ? true : false
    end
    # 選択肢
    if data.key?('possible_values') && data['field_format'] == 'list'
      if data['possible_values'].is_a?(Array)
        choice_values = data['possible_values'].map { |item| item.is_a?(Hash) ? item.value : item }
        possible_values = choice_values.join("\n")
      else
        possible_values = data['possible_values']
      end
      cf.possible_values = possible_values
    end
    # ロール
    if data.key?('user_role') && data['field_format'] == 'user'
      cf.user_role = Role.where(name: data['user_role']).pluck(:id).map {|v| v.to_s }
    end
    # ステータス
    if data.key?('version_status') && data['field_format'] == 'version'
      cf.version_status = data['version_status'].select { |v| ['open', 'locked', 'closed'].include?(v) }
    end
    # 許可する拡張子
    if data.key?('extensions_allowed') && data['field_format'] == 'attachment'
      extensions_allowed = data['extensions_allowed']
      extensions_allowed = data['extensions_allowed'].join(',') if data['extensions_allowed'].is_a?(Array)
      cf.extensions_allowed = extensions_allowed
    end
    # フィルタとして使用
    if data.key?('is_filter') && data['field_format'] != 'attachment'
      cf.is_filter = data['is_filter'] ? true : false
    end
    # 表示
    if data.key?('visible')
      if cf.is_a?(UserCustomField)
        cf.visible = !!data['visible']
      elsif data['visible'].is_a?(Array)
        cf.role_ids = Role.where(name: data['visible']).pluck(:id).map {|v| v.to_s }
        cf.visible = false
      else
        cf.visible = !!data['visible']
      end
    end

    # 表示順序
    cf.position = data['position'] if data['position'].present?

    if cf.is_a?(UserCustomField)
      # ユーザーカスタムフィールドの固有処理
      # 編集可能
      cf.editable = true
      if data.key?('editable')
        cf.visible = !!data['editable']
      end
    end
    if cf.is_a?(IssueCustomField)
      # チケットカスタムフィールドの固有処理
      # トラッカー
      if data.key?('trackers') && data['trackers'].present?
        trackers = data['trackers'].map do |t|
          if t.is_a?(Hash)
            if t.key?('id') && t.id
              tracker = Tracker.find_by_id(t.id)
            else
              tracker = Tracker.find_by_name(t.name)
            end
          else
            tracker = Tracker.find_by_name(t)
          end
        end
        cf.tracker_ids = trackers.pluck(:id).map {|v| v.to_s }
      end
      # プロジェクト
      cf.is_for_all = true
      if data.key?('projects') && data['projects'].present?
        cf.is_for_all = false
        projects = data['projects'].map do |p|
          if p.is_a?(Hash)
            if p.key?('id') && item.id
              project = Project.find_by_id(p.id)
            else
              project = Project.find_by_name(p.name)
            end
          else
            project = Project.find_by_name(p)
          end
          project
        end
        cf.project_ids = projects.pluck(:id).map {|v| v.to_s }
      end
    end
    cf.save!
    puts cf.name
  end

  ## プロジェクトのインポート
  def import_project(identifier, data, parent=nil)
    project = Project.find_by_identifier(identifier)
    project ||= Project.new({identifier: identifier})
    # 名称
    project.name = data['name'] || identifier
    # 説明
    project.description = data['description'] if data.key?('description')
    # ホームページ
    project.homepage = data['homepage'] if data.key?('homepage')
    # 公開
    project.is_public = data['is_public'] if data.key?('is_public')
    # モジュール
    # @todo モジュール割当を有効にするとプロジェクト登録時に`Validation failed: Enabled modules is invalid`が発生
    # @todo モジュール割当を有効にするとプロジェクト更新時に`Failed to replace enabled_modules because one or more of the new records could not be saved.`が発生
    # project.enabled_module_names = data['modules'] if data.key?('modules')
    # メンバーを継承
    project.inherit_members = !!data['inherit_members'] if data.key?('inherit_members')
    # 親プロジェクト
    project.parent_id = parent.id if parent
    # トラッカー
    if data.key?('trackers')
      project.tracker_ids = Tracker.where(:name => data['trackers']).pluck(:id)
    end
    # カスタムフィールド
    if data.key?('custom_fields')
      custom_field_values = {}
      data['custom_fields'].each do |custom_field|
        if custom_field['id'].present?
          cf = ProjectCustomField.find_by_id(custom_field['id'])
        else
          cf = ProjectCustomField.find_by_name(custom_field['name'])
        end
        custom_field_values[cf.id] = custom_field['value'] if cf
      end
      project.custom_field_values = custom_field_values
    end
    project.save!
    puts project
    ## メンバー
    if data.key?('members')
      project.delete_all_members
      data['members'].each do |member|
        user = User.find_by_login(member['login'])
        role_ids = Role.where(name: member['role']).pluck(:id)
        if user && role_ids.present?
          project_member = Member.new(:project => project, :user_id => user.id)
          project_member.role_ids = role_ids
          project_member.save!
        end
      end
    end
    if data.key?('wiki_pages') && data['wiki_pages'].present?
      import_wiki_pages(project, data['wiki_pages'])
      # @todo メインページを設定できるようにする必要あり
    end
    if data.key?('issue_queries') && data['issue_queries'].present?
      data['issue_queries'].each do |issue_query|
        import_issue_query(issue_query, project)
      end
    end
    if data.key?('issue_queries') && data['time_entry_queries'].present?
      data['time_entry_queries'].each do |time_entry_query|
        import_time_entry_query(time_entry_query, project)
      end
    end
    if data.key?('childlen') && data['childlen']
      data['childlen'].each do |child_identifier, child_data|
        import_project child_identifier, child_data, project
      end
    end
  end

  ## Wikiページのインポート
  def import_wiki_pages(project, wiki_pages, parent=nil)
    wiki_pages.each do |page_name, data|
      wiki_page = project.wiki.find_or_new_page(page_name)
      wiki_page.parent_title = parent.title if parent
      content = wiki_page.content || WikiContent.new({page: wiki_page})
      content.text ||= "#{page_name}\n----------------------------\n\n{{child_pages}}"
      if data && data['content']
        content.text = data['content']
      end
      content.author = User.current
      wiki_page.save_with_content(content)
      wiki_page.save!
      if data && data.key?('childlen') && data['childlen']
        import_wiki_pages project, data['childlen'], wiki_page
      end
    end
  end

  ## チケットのカスタムクエリーのインポート
  def import_issue_query(data, project=nil, name_output=false)
    if data['id'].present?
      issue_query = IssueQuery.find_by_id(data['id'])
    else
      project_id = project ? project.id : nil
      issue_query = IssueQuery.find_by_name_and_project_id(data['name'], project_id)
    end
    unless custom_query
      issue_query = IssueQuery.new({name: data['name']})
      # 表示：全てのユーザー
      issue_query.visibility = 2
      # 全プロジェクト向け
      issue_query.project = project
      issue_query.user = User.current
    end
    ## 名前
    issue_query.name = data['name']
    ## フィルター
    filter_fields = []
    filter_operators = {}
    filter_values = {}
    data['filters'].each do |key, value|
      field_name = key
      field_filter_operator = value['operator'] || value['op']
      field_filter_value = value['values'] || []
      case key
      when 'status'
        field_name = 'status_id'
        field_filter_value = IssueStatus.where(:name => field_filter_value).pluck(:id).map {|item| item.to_s }
      when 'tracker'
        field_name = 'tracker_id'
        field_filter_value = Tracker.where(:name => field_filter_value).pluck(:id).map {|item| item.to_s }
      when 'priority'
        field_name = 'priority_id'
        field_filter_value = IssuePriority.where(:name => field_filter_value).pluck(:id).map {|item| item.to_s }
      when 'author'
        field_name = 'author_id'
        field_filter_value = User.where(:login => field_filter_value).pluck(:id).map {|item| item.to_s }
        field_filter_value.push 'me' if field_filter_value.include?('me')
      when 'assigned_to'
        field_name = 'assigned_to_id'
        field_filter_value = User.where(:login => field_filter_value).pluck(:id).map {|item| item.to_s }
        field_filter_value.push 'me' if field_filter_value.include?('me')
      end
      filter_fields.push field_name
      filter_operators[field_name] = field_filter_operator
      filter_values[field_name] = field_filter_value
    end
    form_params = {
      :c => [],
      :sort => [
        ['id', 'desc']
      ]
    }
    ## フィルター
    form_params[:fields] = filter_fields
    form_params[:operators] = filter_operators
    form_params[:values] = filter_values
    ## 説明
    if data.key?('description') && data['columns'].present?
      form_params[:description] = data['description']
    end
    ## 表示項目
    if data.key?('columns') && data['columns'].present?
      form_params[:c] = data['columns']
    end
    ## 並び順
    if data.key?('sort') && data['sort'].present?
      form_params[:sort] = []
      data['sort'].each do |sort|
        form_params[:sort].push [sort['field'], sort['order']]
      end
    end
    ## グループ条件
    form_params[:group_by] = data['group_by'] if data.key?('group_by')
    ## 合計
    form_params[:t] = data['total'] if data.key?('total')
    issue_query.build_from_params form_params
    issue_query.save!
    puts issue_query.name if name_output
  end

  ## 時間管理のカスタムクエリーのインポート
  def import_time_entry_query(data, project=nil)
    puts '時間管理のカスタムクエリーのインポートはまだ未実装'
  end
end

import = Import.new
## システム管理者情報の更新
import.admin
## ステータスのインポート
import.status
## トラッカーのインポート
import.tracker
## ロールのインポート
import.role

## チケットの優先度をインポート
import.priority
## 文書カテゴリをインポート
import.document_category
## 作業分類をインポート
import.time_entry_activity

## チケットのカスタムフィールドをインポート
import.issue_custom_field
## プロジェクトのカスタムフィールドをインポート
import.project_custom_field
## ユーザーのカスタムフィールドをインポート
import.user_custom_field

## Redmine本体およびプラグインの設定をインポート
import.setting

## ワークフローをインポート
import.workflow
## フィールド権限をインポート
import.workflow_permission

## ユーザーをインポート
import.user
## グループをインポート
import.group

## チケットのカスタムクエリをインポート
import.issue_query
## プロジェクトのカスタムクエリをインポート
import.project_query
## 作業時間のカスタムクエリをインポート
import.time_entry_query
## プロジェクトをインポート
import.project
## 添付ファイルをインポート
import.attachment

## プラグインの設定をインポート

### redmine_message_customizeの設定をインポート
import.message_customize
### view_customizeの設定をインポート
import.view_customize
### redmine_issue_templatesの設定をインポート
import.issue_template
import.note_template
