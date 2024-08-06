#!/usr/bin/env ruby

require 'yaml'

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
    if File.exist?(data_file)
      data = YAML.load_file(data_file)
      if data.present?
        User.update!(1, data)
      end
      File.delete(data_file)
    end
  end

  ## ステータスのインポート
  def status
    data_file = File.join(TMP_DIR, 'status.yml')
    if File.exist?(data_file)
      statuses = YAML.load_file(data_file)
      if statuses.present?
        statuses.each do |item|
          if item['id'].present?
            status = IssueStatus.find_by_id(item['id'])
            status.name = item['name']
          else
            status = IssueStatus.find_by_name(item['name'])
          end
          status ||= IssueStatus.new
          status.safe_attributes = item
          status.position = item['position'] if item['position'].present?
          status.save!
        end
      end
      File.delete(data_file)
    end
  end

  ## トラッカーのインポート
  def tracker
    data_file = File.join(TMP_DIR, 'tracker.yml')
    if File.exist?(data_file)
      trackers = YAML.load_file(data_file)
      if trackers.present?
        puts "Import Tracker"
      end
      File.delete(data_file)
    end
  end

  ## ロールのインポート
  def role
    data_file = File.join(TMP_DIR, 'role.yml')
    if File.exist?(data_file)
      roles = YAML.load_file(data_file)
      if roles.present?
        puts "Import Role"
      end
      File.delete(data_file)
    end
  end

  ## ワークフローのインポート
  def workflow
    data_file = File.join(TMP_DIR, 'workflow.yml')
    if File.exist?(data_file)
      workflow = YAML.load_file(data_file)
      if workflow.present?
        puts "Import workflow"
      end
      File.delete(data_file)
    end
  end

  ## 設定のインポート
  def setting
    data_file = File.join(TMP_DIR, 'setting.yml')
    if File.exist?(data_file)
      setting = YAML.load_file(data_file)
      if setting.present?
        puts "Import Setting"
        ## Redmine本体の設定を取り込み
        redmine_setting = setting.reject {|key, value| key.start_with?('plugin_') }
        if redmine_setting.key?('default_projects_trackers')
          redmine_setting['default_projects_tracker_ids'] = Tracker.where(:name => redmine_setting['default_projects_trackers']).pluck(:id).map {|item| item.to_s }
          redmine_setting.delete('default_projects_trackers')
        end
        if redmine_setting.present?
          Setting.set_all_from_params(redmine_setting)
        end
        ## プラグインの設定を取り込み
        plugin_settings = setting.select {|key, value| key.start_with?('plugin_') }
        if plugin_settings.present?
          plugin_settings.each do |plugin_name, plugin_setting|
            if Redmine::Plugin.installed? plugin_name.sub('plugin_', '').to_s
              Setting.send plugin_name + '=', plugin_setting.with_indifferent_access
            end
          end
        end
      end
      File.delete(data_file)
    end
  end

  ## ユーザーのインポート
  def user
    data_file = File.join(TMP_DIR, 'user.yml')
    if File.exist?(data_file)
      users = YAML.load_file(data_file)
      if users.present?
        puts "Import User"
      end
      File.delete(data_file)
    end
  end

  ## グループのインポート
  def group
    puts "Import Group"
  end

  def priority
    puts "Import priority"
  end

  def document_category
    puts "Import document category"
  end

  def time_entry_activity
    puts "Import time entry activity"
  end

  def project_custom_field
    puts "Import project custom field"
  end

  def issue_custom_field
    puts "Import issue custom field"
  end

  def user_custom_field
    puts "Import user custom field"
  end

  def project
    puts "Import Project"
  end

  def custom_field
    allow_length_formats = ['string', 'text', 'link', 'int', 'float']
    allow_regexp_formats = ['string', 'text', 'link', 'int', 'float']
    allow_default_value_formats = ['string', 'text', 'link', 'int', 'float', 'date', 'bool']
    allow_text_formatting_formats = ['string', 'text']
    allow_url_pattern_formats = ['string', 'link', 'date', 'int', 'float', 'list', 'bool']
    allow_edit_tag_style_formats = ['version', 'user', 'list', 'bool', 'enumeration']
    allow_multiple_formats = ['version', 'user', 'list', 'enumeration']
    allow_searchable_formats = ['string', 'text', 'list']

    # 形式
    cf.field_format = setting['field_format']
    # 名称
    cf.name = setting['name']
    # 説明
    cf.description = setting['description'] if setting.key?('description')
    # 必須
    cf.is_required = !!setting['is_required'] if setting.key?('is_required')
    # 最小値または最小文字列長
    if setting.key?('min_length') && allow_length_formats.include?(setting['field_format'])
      cf.min_length = setting['min_length'].to_s
    end
    # 最大値値または最小文字列長
    if setting.key?('max_length') && allow_length_formats.include?(setting['field_format'])
      cf.max_length = setting['max_length'].to_s
    end
    # 正規表現
    if setting.key?('regexp') && allow_regexp_formats.include?(setting['field_format'])
      cf.regexp = setting['regexp']
    end
    # 初期値
    if setting.key?('default_value') && allow_default_value_formats.include?(setting['field_format'])
      cf.default_value = setting['default_value'].to_s
    end
    # テキスト書式
    if setting.key?('text_formatting') && allow_text_formatting_formats.include?(setting['field_format'])
      cf.text_formatting = setting['text_formatting'] ? true : false
    end
    # 値に設定するリンクURL
    if setting.key?('url_pattern') && allow_url_pattern_formats.include?(setting['field_format'])
      cf.url_pattern = setting['url_pattern']
    end
    # 表示(入力形式)
    if setting.key?('edit_tag_style') && allow_edit_tag_style_formats.include?(setting['field_format'])
      edit_tag_style = nil
      if ['check_box', 'radio'].include?(setting['edit_tag_style'])
        edit_tag_style = setting['edit_tag_style']
        cf.edit_tag_style = edit_tag_style
      end
    end
    # 複数選択
    if setting.key?('multiple') && allow_multiple_formats.include?(setting['field_format'])
      cf.multiple = setting['multiple'] ? true : false
    end
    # 検索対象
    if setting.key?('searchable') && allow_searchable_formats.include?(setting['field_format'])
      cf.searchable = setting['searchable'] ? true : false
    end
    # 選択肢
    if setting.key?('possible_values') && setting['field_format'] == 'list'
      if setting['possible_values'].is_a?(Array)
        choice_values = setting['possible_values'].map {|item| item.is_a?(Hash) ? item.value : item }
        possible_values = choice_values.join("\n")
      else
        possible_values = setting['possible_values']
      end
      cf.possible_values = possible_values
    end
    # ロール
    if setting.key?('user_role') && setting['field_format'] == 'user'
      cf.user_role = Role.where(:name => setting['user_role']).pluck(:id).map {|v| v.to_s }
    end
    # ステータス
    if setting.key?('version_status') && setting['field_format'] == 'version'
      cf.version_status = setting['version_status'].select { |v| ['open', 'locked', 'closed'].include?(v) }
    end
    # 許可する拡張子
    if setting.key?('extensions_allowed') && setting['field_format'] == 'attachment'
      extensions_allowed = setting['extensions_allowed']
      extensions_allowed = setting['extensions_allowed'].join(',') if setting['extensions_allowed'].is_a?(Array)
      cf.extensions_allowed = extensions_allowed
    end
    # フィルタとして使用
    if setting.key?('is_filter') && setting['field_format'] != 'attachment'
      cf.is_filter = setting['is_filter'] ? true : false
    end
    # 表示
    if setting.key?('visible')
      if cf.is_a?(UserCustomField)
        cf.visible = !!setting['visible']
      elsif setting['visible'].is_a?(Array)
        cf.role_ids = Role.where(:name => setting['visible']).pluck(:id).map {|v| v.to_s }
        cf.visible = false
      else
        cf.visible = !!setting['visible']
      end
    end

    # 表示順序
    cf.position = setting['position'] if setting['position'].present?

    if cf.is_a?(UserCustomField)
      # ユーザーカスタムフィールドの固有処理
      # 編集可能
      cf.editable = true
      if setting.key?('editable')
        cf.visible = !!setting['editable']
      end
    end
    if cf.is_a?(IssueCustomField)
      # チケットカスタムフィールドの固有処理
      # トラッカー
      if setting.key?('trackers') && setting['trackers'].present?
        trackers = setting['trackers'].map do |item|
          if item.is_a?(Hash)
            if item.key?('id') && item.id
              tracker = Tracker.find_by_id(item.id)
            else
              tracker = Tracker.find_by_name(item.name)
            end
          else
            tracker = Tracker.find_by_name(item)
          end
        end
        cf.tracker_ids = trackers.pluck(:id).map {|v| v.to_s }
      end
      # プロジェクト
      cf.is_for_all = true
      if setting.key?('projects') && setting['projects'].present?
        cf.is_for_all = false
        projects = setting['projects'].map do |item|
          if item.is_a?(Hash)
            if item.key?('id') && item.id
              project = Project.find_by_id(item.id)
            else
              project = Project.find_by_name(item.name)
            end
          else
            project = Project.find_by_name(item)
          end
        end
        cf.project_ids = projects.pluck(:id).map {|v| v.to_s }
      end
    end
    cf.save!
  end
end

import = Import.new
## システム管理者情報の更新
import.admin
## トラッカーのインポート
import.tracker
## ロールのインポート
import.role
## ステータスのインポート
import.status
## ワークフローをインポート
import.workflow

## Redmine本体およびプラグインの設定をインポート
import.setting

## ユーザーをインポート
import.user
## グループをインポート
import.group

## 優先順位をインポート
import.priority
## 文書カテゴリーをインポート
import.document_category
## 作業分類をインポート
import.time_entry_activity

## プロジェクトのカスタムフィールドをインポート
import.project_custom_field
## チケットのカスタムフィールドをインポート
import.issue_custom_field
## ユーザーのカスタムフィールドをインポート
import.user_custom_field
