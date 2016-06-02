require 'json'
require 'httparty'
require 'pry'
require 'shopify_api'
require 'yaml'

@outcomes = {
  errors: [],
  skipped: [],
  found_product_with_query_type: []
  # responses: []
}

#Load secrets from yaml file & set data values
data = YAML::load( File.open( 'config/secrets.yml' ))
SECURE_URL_BASE = data['url_base']
API_DOMAIN = data['api_domain']

#Constants
DIVIDER = '------------------------------------------'
DELAY_BETWEEN_REQUESTS = 0.11
NET_INTERFACE = HTTParty
STARTPAGE = 1
ENDPAGE = 96

MANUAL_TYPE_TO_FIND = "Formal"

#Need to update to include page range as arguments for do_page_range
# startpage = ARGV[1].to_i
# endpage = ARGV[2].to_i
def main
  if ARGV.empty?
    #Type to find in none when script called
    current_type_to_find = MANUAL_TYPE_TO_FIND
  else
    current_type_to_find = ARGV[0]
  end

  puts "starting at #{Time.now}"
  puts "finding #{current_type_to_find}"

  do_page_range

  puts "finished at #{Time.now}"
  puts "found #{current_type_to_find}"

  File.open(filename, 'w') do |file|
    file.write @outcomes.to_json
  end

  @outcomes.each_pair do |k,v|
    puts "#{k}: #{v.size}"
  end
end

def filename
  "data/find_product_ids_by_type_#{Time.now.strftime("%Y-%m-%d_%k%M%S")}.json"
end

def do_page_range
  (STARTPAGE .. ENDPAGE).to_a.each do |current_page|
    do_page(current_page)
  end
end

def do_page(page_number)
  puts "Starting page #{page_number}"

  products = get_products(page_number)

  # counter = 0
  products.each do |product|
    @product_id = product['id']
    do_product(product)
  end

  puts "Finished page #{page_number}"
end

def get_products(page_number)
  response = secure_get("/products.json?page=#{page_number}")

  JSON.parse(response.body)['products']
end

def get_product(id)
  JSON.parse( secure_get("/products/#{id}.json").body )['product']
end

def do_product_by_id(id)

  do_product(get_product(id))
end

def do_product(product)
  begin
    puts DIVIDER
    product_type = product['product_type']

    if ARGV.empty?
      current_type_to_find = MANUAL_TYPE_TO_FIND #Type to find
    else
      current_type_to_find = ARGV[0]
    end

    if ( product_type == current_type_to_find )
      found_product_with_query_type(product)
    else
      skip(product)
    end
  rescue Exception => e
    @outcomes[:errors].push @product_id
    puts "error on product #{product['id']}: #{e.message}"
    puts e.backtrace.join("\n")
    raise e
  end
end

def skip(product)
  @outcomes[:skipped].push @product_id
  puts "Skipping product #{product['id']}"
end

def found_product_with_query_type(product)
  @outcomes[:found_product_with_query_type].push @product_id
  puts "Found product #{product['id']} with type #{product['product_type']}"
end

def secure_get(relative_url)
  sleep DELAY_BETWEEN_REQUESTS
  url = SECURE_URL_BASE + relative_url
  result = NET_INTERFACE.get(url)
end

# def secure_put(relative_url, params)
#   sleep DELAY_BETWEEN_REQUESTS
#
#   url = SECURE_URL_BASE + relative_url
#
#   result = NET_INTERFACE.put(url, body: params)
#
#   @outcomes[:responses].push({
#     method: 'put', requested_url: url, body: result.body, code: result.code
#   })
# end
#
# def put(url, params)
#   NET_INTERFACE.put(url, query: params)
# end

main
