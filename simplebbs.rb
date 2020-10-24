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
	redirect '/bbs'
end

post '/message' do
	msg = BBS.new
	# 0.1秒毎にIDを生成してしたとき、重複するIDが生成されるまでの期待値が100年になるようにする。
	# 鳩の巣原理と誕生日のパラドクスより、70bitの乱数でこれを達成できることがわかる
	# hex文字列で乱数を生成するため、72bitの乱数を生成する。
	# SecureRandom.hex(n)はn*2の長さの文字列を返す。1文字につき4bitのデータを持つため、引数は9
	msg.id = SecureRandom.hex(9)
	msg.name = "#{sanitize(params[:name].rstrip)}"
	msg.text = "#{sanitize(params[:text].rstrip)}"
    msg.text = allow_html_pairs(msg.text)

	if is_valid_size(eliminate_tag(msg.name), 0, 20) && is_valid_size(eliminate_tag(msg.text), 0, 20) then
		begin
            msg.text = allow_html_single(msg.text, "img")
            msg.save
		rescue ActiveRecord::RecordNotUnique
			redirect "/badrequest"
		end
	end

	redirect "/bbs"
end

get '/bbs' do 
	@s = BBS.all
	erb :bbs
end

get '/badrequest' do
	erb :badrequest
end

post '/del' do
  begin
	msg = BBS.find(params[:id])
	msg.destroy
  rescue
  end
	redirect "/bbs"
end

helpers do 
	def sanitize(text)
		dame = /<|>|!|"|#|$|%|&|`|'|\*/
		iiyo = {"<"=>"&#060", ">"=>"&#062", "!"=>"&#033", "\""=>"&#034", "#"=>"&#035", "%"=>"&#037", "&"=>"&#038", "'"=>"&#039", "\*"=>"&#042"}

		text = text.gsub(dame){iiyo[$&]}

        return text
	end

    def desanitize(text)
      iiyo = /\&\#060|\&\#062|\&\#033|\&\#034|\&\#035|\&\#037|\&\#039|\&\#042/
      moto = {"&#060"=>"<", "&#062"=>">", "&#033"=>"!", "&#034"=>"\"", "&#035"=>"#", "&#037"=>"%", "&#038"=>"&", "&#039"=>"'", "&#042"=>"*"}
      text = text.gsub(iiyo){moto[$&]}
      return text
    end

    def allow_html_pairs(text)
      text = allow_html_pair(text, "strong")
      text = allow_html_pair(text, "h1")
      text = allow_html_pair(text, "h2")
      text = allow_html_pair(text, "h3")
      text = allow_html_pair(text, "h4")
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
        if text.match(/\&\#060#{tag}.*?\&\#060\/#{tag}\&\#062/) != nil
          text = text.sub(/\&\#060#{tag}/, "<#{tag}")
          text = text.sub(/\&\#062/, ">")
          text = text.sub(/\&\#060\/#{tag}\&\#062/, "</#{tag}>")
          text = allow_html_pair(text, tag)
        end
        return text
    end

    def allow_html_single(text, tag)
      matched = text.match(/\&\#060#{tag}.*?#062/)
      if matched != nil
          matched = matched.string
          html = desanitize(matched)
          puts "#{html}"
          text = text.sub(/#{matched}/, html)
          puts "#{text}"
          text = allow_html_single(text, tag)
      end
      return text
    end
end

def is_valid_size(text, min, max) 
	length = text.size

	if min < length && length <= max then
		return true
	else
		return false
	end
end

def eliminate_tag(text)
  return text.gsub(/<.*?>/, "")
end
