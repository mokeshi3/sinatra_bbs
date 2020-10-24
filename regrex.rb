text = "<h1><h1>test</h1><h2></h2>"

matched = text.match(/<h1>.*?<\/h1>/)
puts("#{matched}")
