# weblog-jekyll

Source code of mrguzman.me.uk weblog

## Requirements

### Ruby

Install dependencies (in Ubuntu)
```
sudo apt-get install git-core curl zlib1g-dev build-essential \
  libssl-dev libreadline-dev libyaml-dev libsqlite3-dev sqlite3\
  libxml2-dev libxslt1-dev libcurl4-openssl-dev \
  python-software-properties libffi-dev nodejs
```

Install ruby using `rbenv`
```
cd
git clone https://github.com/rbenv/rbenv.git ~/.rbenv
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
exec $SHELL

git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
echo 'export PATH="$HOME/.rbenv/plugins/ruby-build/bin:$PATH"' >> ~/.bashrc
exec $SHELL

rbenv install 2.4.1
rbenv global 2.4.1
ruby -v
```

Install bundler
```
gem install bundler
rbenv rehash
```

### Jekyll
```
gem install jekyll
```

### PlantUML
```
sudo apt-get install plantuml
```

### Generate tags pages
```
ruby _gentags.rb
```

### Run Jekyll
```
bundle exec jekyll serve
```
