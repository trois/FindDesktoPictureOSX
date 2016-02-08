#!/usr/bin/env ruby
# coding: utf-8
require 'optparse'
require 'pp'

# sqlite3 -header  "$HOME/Library/Application Support/Dock/desktoppicture.db" \
# "  select ROWID,* from preferences; \
#    select ROWID,* from data; \
#    select ROWID,* from pictures; \
#    select ROWID,* from spaces; \
#    select ROWID,* from displays; \
#    select ROWID,* from prefs;  \
# "

# data          rowid|value
# preferences   rowid|key|data_id|picture_id
def getpicts
  db = "#{Dir.home}/Library/Application Support/Dock/desktoppicture.db"
  er = '> /dev/stdout 2>&1'

  sq1 = 'SELECT ROWID,* FROM data ;'
  sq2 = 'SELECT ROWID,* FROM preferences ;'
  sq3 = 'SELECT ROWID,* FROM pictures ;'

  ky1 = %w( rowid value)
  ky2 = %w( rowid key data_id picture_id )
  ky3 = %w( rowid space_id display_id)

  dt1 = `sqlite3 "#{db}" "#{sq1}" #{er}`
        .split(/\n/)
        .map { |m| m.split('|') }
        .map! { |m| Hash[*ky1.zip(m).flatten] }

  dt2 = `sqlite3 "#{db}" "#{sq2}" #{er}`
        .split(/\n/)
        .map { |m| m.split('|') }
        .map! { |m| Hash[*ky2.zip(m).flatten] }

  dt3 = `sqlite3 "#{db}" "#{sq3}" #{er}`
        .split(/\n/)
        .map { |m| m.split('|') }
        .map! { |m| Hash[*ky3.zip(m).flatten] }

  data  = dt1
  files = dt2.select { |e| e['key'] == '16' }
  dirs  = dt2.select { |e| e['key'] == '10' }
  desk = dt3

  arr = files.map do |m|
    # 画像
    did = m['data_id']
    m['file'] = data.find { |x| x['rowid'] == did }.fetch('value')

    # フォルダ
    pid = m['picture_id']
    did2 = dirs.find { |x| x['picture_id'] == pid }.fetch('data_id')
    m['dir'] = data.find { |x| x['rowid'] == did2 }.fetch('value')

    # 画面 ＝ display + space
    pid = m['picture_id']
    dsp = desk.find { |x| x['rowid'] == pid }
    m['space_id'] = dsp['space_id']
    m['display_id'] = dsp['display_id']

    # path
    path = m['dir'] + '/' + m['file']
  	 fail(path.to_s) if File.exist?(path)
  	 m['path'] = path
    next m
  end

  # nil,空白の画面の削除
  arr.delete_if{|m|
  	 m.values.any?{|w| w == nil || w == ""}
  }

  return arr
end

#---------------------------------------
def help
  h = []
  fmt = "  -%s     %s"
  h <<
    "usage : ruby #{$0} option" <<
    format(fmt, 'h', 'help') <<
    format(fmt, 'l', '最近更新を選択(デフォルト)') <<
    format(fmt, 's', '最近更新のパス') <<
    format(fmt, 'a', '全スペースの画像パス') <<
    format(fmt, 'd', 'スペース＆ディスプレー情報付き')

  puts h.join("\n")
end

def select_last(arr)
  path = File.expand_path(arr.last['path'])
  cmd = "open -R #{path}"
  # print cmd
  system cmd
end

def out_last(arr)
  puts arr.last['path']
end

def allspaces(arr, detail = nil)
  out = []
  out << sprintf("#%4s:%-5s %s", 'disp', 'space', 'path') if detail
  arr.each do|e|
    d = e['display_id']
    s = e['space_id']
    pt = e['path']
    out << if detail
             sprintf(" %4s:%-5s %s", d, s, pt)
           else
             pt
           end # if
  end
  return out.join("\n")
end

def out_allspc(arr)
  puts allspaces(arr)
end

def out_detail(arr)
  puts allspaces(arr, true)
end

#---------------------------------------
if $0 == __FILE__
  params = ARGV.getopts('hlsad')
  #  puts "\n解析されたハッシュ\n#{params}"

  help() if params['h']

  arr = getpicts()
  select_last(arr) if params['s'] || params.all?{|k, v| v == false }
  out_last(arr) if params['l']
  out_allspc(arr)  if params['a']
  out_detail(arr) if params['d']

end
