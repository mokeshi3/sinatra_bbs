require "sinatra"
require "digest/md5"
require "active_record"
require "securerandom"

ActiveRecord::Base.configurations = YAML.load_file("database.yml")
ActiveRecord::Base.establish_connection :development

class BBS < ActiveRecord::Base
end

set :environment, :production

get '/' do
	redirect '/bbs/1/5'
end

post '/message/:page/:contents' do |page, contents|
	msg = BBS.new
	# 0.1秒毎にIDを生成してしたとき、重複するIDが生成されるまでの期待値が100年になるようにする。
	# 鳩の巣原理と誕生日のパラドクスより、70bitの乱数でこれを達成できることがわかる
	# hex文字列で乱数を生成するため、72bitの乱数を生成する。
	# SecureRandom.hex(n)はn*2の長さの文字列を返す。1文字につき4bitのデータを持つため、引数は9
    msg.id = SecureRandom.hex(1)
    puts "I create id #{msg.id}"
	msg.name = "#{params[:name].rstrip}"
	msg.message = "#{params[:text].rstrip}"
    msg.write_time = Time.now.to_i
    if is_valid_size(msg.name, 0, 200) && is_valid_size(msg.message, 0, 1000)
      begin
          msg.name = sanitize(msg.name)
          msg.message = sanitize(msg.message)
          msg.message = allow_html_pairs(msg.message)
          if is_valid_size(msg.name, 0, 800) && is_valid_size(msg.message, 0, 4000) != 0
              msg.save
          end
      rescue ActiveRecord::RecordNotUnique
        puts "#{msg.id} is not unique!"
        call env.merge("/message/#{page}/#{contents}" => "/message/#{page}/#{contents}")
      rescue
      end
    end

	redirect "/bbs/#{page}/#{contents}"
end

get '/bbs' do
    redirect '/bbs/1/5'
end

get '/bbs/:page' do |page|
  redirect "/bbs/#{page}/5"
end

get '/bbs/:page/:contents' do |page, contents|
    if not page.is_number? 
        redirect '/bbs/1/5'
    end
    page = page.to_i

    if not page.is_number?
      redirect "/bbs/#{page}/5"
    end
    contents = contents.to_i

    if page <= 0 
      redirect "/bbs/1/#{contents}"
    end

    if contents <= 0 
      redirect "/bbs/#{page}/5"
    end

    @s = BBS.all.order("write_time")
    max_page = @s.size/contents + if @s.size%contents != 0 then 1 else 0 end

    # 何もないページが生成されないようにする
    if page > max_page && @s.size != 0
      redirect "bbs/#{max_page}/#{contents}"
    end

    # 残りの投稿数
    rest = @s.size - contents*(page-1)
    if rest < 0 
      rest = 0
    end

    @s = @s.take(page*contents).last(if rest >= contents then contents else rest end)
    @page = page
    @contents = contents

    paging = []
    (page-2..page+2).each { |p|
      if p <= 1 
        next
      end

      if p > max_page 
        next
      end

      paging.append(p)
    }

    if paging.size == 0
      paging = [1]
    end

    if paging[0] > 2 
      paging.insert(0, 1, -1)
    elsif paging[0] == 2
      paging.insert(0, 1)
    end

    if paging[-1] == max_page-1
      paging.append(max_page)
    elsif paging[-1] <= max_page-2
      paging.append(-1)
      paging.append(max_page)
    end

    @paging = paging
	erb :bbs
end

get '/badrequest' do
	erb :badrequest
end

post '/del/:page/:contents' do |page, contents|
  begin
	msg = BBS.find(sanitize(params[:id]))
	msg.destroy
  rescue
  end
  redirect "/bbs/#{page}/#{contents}"
end

def sanitize(text)
  dame = /<|>|"|#|`|'|\*|\\|;|:/
  iiyo = {"<"=>"&#060", ">"=>"&#062", "\""=>"&#034", "#"=>"&#035", "`"=>"&#096", "'"=>"&#039", "\*"=>"&#042", "\\"=>"&#092", ";"=>"&#059", ":"=>"&#058"}

  text = text.gsub(dame){iiyo[$&]}

  return text
end

def desanitize(text)
  iiyo = /\&\#060|\&\#062|\&\#034|\&\#035|\&\#096|\&\#039|\&\#042|\&\#092|\&\#059|\&\#058/
  moto = {"&#060"=>"<", "&#062"=>">", "&#034"=>"\"", "&#035"=>"#", "&#096"=>"`", "&#039"=>"'", "&#042"=>"*", "&#092"=>"\\", "&#059"=>";", "&#058"=>":"}
  text = text.gsub(iiyo){moto[$&]}
  return text
end

def allow_html_pairs(text)
  text = allow_html_pair(text, "strong")
  text = allow_html_pair(text, "font")
  text = allow_html_pair(text, "b")
  text = allow_html_pair(text, "i")
  text = allow_html_pair(text, "s")
  text = allow_html_pair(text, "u")
  text = allow_html_pair(text, "strike")
  text = allow_html_pair(text, "em")
  text = allow_html_pair(text, "del")
  text = allow_html_pair(text, "code")
  return text
end

def allow_html_pair(text, tag)
  if text.match(/\&\#060#{tag}.*?\&\#062\&\#060\/#{tag}\&\#062/) != nil
      text = text.sub(/\&\#060#{tag}\&\#062/, "<#{tag}>")
      text = text.sub(/\&\#060\/#{tag}\&\#062/, "</#{tag}>")
      text = allow_html_pair(text, tag)
    end
    return text
end

def is_valid_size(text, min, max) 
	length = text.size

	if min < length && length <= max then
		return true
	else
		return false
	end
end

class Object
  def is_number?
    to_f.to_s == to_s || to_i.to_s == to_s
  end
end
