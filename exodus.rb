#    Mount Exodus - Movable Type to WordPress Web Application Utility
#    Copyright @ 2014 Joe Wilson
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU Affero General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU Affero General Public License for more details.
#
#    You should have received a copy of the GNU Affero General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'liquid'
require 'sinatra'
require 'yaml'
require 'sanitize'

# ruby-mtexport
# https://github.com/mchung/ruby-mtexport
# https://github.com/joewils/ruby-mtexport
require_relative 'ruby-mtexport/mtexport_parser'
require_relative 'ruby-mtexport/mt_to_wordpress'

Liquid::Template.file_system = Liquid::LocalFileSystem.new('views') 

get '/' do
  liquid :index, :locals => {}
end

get '/rss/:feed_id' do
  content_type 'application/octet-stream'
  attachment('mttowordpress.rss')
  file_name = 'rss/' + Sanitize.fragment(params[:feed_id])
  File.read(file_name)
end

get '/exodus/:plan' do

  plan = 'enterprise'
  price = 69
  plan = params[:plan] 
  list_group_item_class = 'list-group-item-info'
  panel_class = 'panel-primary'

  if params[:plan] == 'professional'
    plan = 'professional'
    price = 49
    list_group_item_class = 'list-group-item-success'
    panel_class = 'panel-success'
  end

  if params[:plan] == 'personal'
    plan = 'personal'
    price = 29
    list_group_item_class = 'list-group-item-danger'
    panel_class = 'panel-danger'
  end

  #query = request.env['rack.request.query_hash']
  #puts query.inspect

  message = false
  if params[:wtf]
    puts params.inspect
    message = 'WTF?  All form fields are required.  Try again.'
  end

  # drink
  liquid :start, 
    :locals => { 
      :plan => plan, 
      :price => price,
      :message => message,
      :panel_class => panel_class,
      :list_group_item_class => list_group_item_class
    }

end

post '/upload' do
  # params
  # puts params.inspect
  if  params['mtexport'] && params['site_url'] && params['typepad_url']
    # keep on truckin'
  elsif params['plan']
    redirect to('/exodus/'+Sanitize.fragment(params['plan'])+'?wtf=1')
  else
    redirect to('/')
  end

  # read the file
  dump = params['mtexport'][:tempfile].read
  
  # use temp file name for archive, force .dump extension
  temp_name = File.basename(params['mtexport'][:tempfile])
  file_name = temp_name + '.dump'

  # typepad url
  # 'http://foo.typepad.com'
  if params['typepad_url']
    typepad_url = Sanitize.fragment(params['typepad_url'])
  else
    typepad_url = '/'
  end

  # site url
  # 'http://www.foo.com'
  if params['site_url']
    site_url = Sanitize.fragment(params['site_url'])
  else
    site_url = typepad_url
  end
  
  # archive file
  File.open('uploads/' + file_name, 'w') do |f|
    f.write(dump)
  end
  
  # parse movable type dump file
  mt = MtexportParser.new(dump)
  mt.parse

  if mt.size
    # produce image list for download
    images = mt.instance_variable_get(:@images)
    image_list = images['fullsize']
    image_list = image_list.merge(images['inline'])
    image_list = image_list.merge(images['popup'])
    image_list = image_list.merge(images['external'])

    # convert mt posts to wordpress rss with updated image paths
    wp = MtToWordPress.new
    wp.base_url = site_url
    wp.mt_url = typepad_url
    wp.image_dir = '/mtimages'
    rss = wp.rss(mt)

    # archive rss
    archive_name = temp_name + '.rss'
    File.open('rss/' + archive_name, 'w') do |f|
      f.write(rss)
    end

    # drink
    liquid :exodus, 
      :locals => { 
        :images => image_list, 
        :rss => rss, 
        :image_dir => '/mtimages', 
        :feed_id => archive_name,
        :plan => Sanitize.fragment(params['plan'])
      }
  else
    return 'Unable to Parse File.' 
  end

end