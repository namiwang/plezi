module Anorexic
	#####
	# this is a Handler stub class for an HTTP echo server.
	class HTTPHost

		# the parameters / settings for the Host.
		attr_reader :params
		# the routing array
		attr_reader :routes

		def initialize params = {}
			@params = params
			@routes = []
			params[:index_file] ||= 'index.html'
			params[:assets_public] ||= '/assets'
			params[:assets_public].chomp! '/'

			@sass_cache = Sass::CacheStores::Memory.new if defined?(::Sass)
			# @sass_cache_lock = Mutex.new
		end

		def add_route path, controller, &block
			routes << Route.new(path, controller, &block)
		end

		def on_request request
			begin
				# render any assets?
				return true if render_assets request

				# send static file, if exists and root is set.
				return true if send_static_file request

				# return if a route answered the request
				routes.each {|r| return true if r.on_request(request) }

				# send folder listing if root is set, directoty listing is set and it exists

				#to-do

				#return error code or 404 not found
				send_by_code request, 404			
			rescue Exception => e
				# return 500 internal server error.
				Anorexic.error e
				send_by_code request, 500
			end
			true
		end

		def render_assets request
			# contine only if assets are defined and called for
			return false unless @params[:assets] && request.path.match(/^#{params[:assets_public]}\/.+/)
			# call callback
			return true if params[:assets_callback] && params[:assets_callback].call(request)
			source_file = File.join(params[:assets], *(request.path.match(/^#{params[:assets_public]}\/(.+)/)[1].split('/')))
			# stop if file name is reserved
			return false if source_file.match(/(scss|sass|coffee|haml)$/)
			target_file = false
			target_file = File.join( params[:root], params[:assets_public], *request.path.match(/^#{params[:assets_public]}\/(.*)/)[1].split('/') )if params[:root]
			if !File.exists?(source_file)
				case source_file
				when /\.css$/
					source_file.gsub! /css$/, 'sass'
					source_file.gsub! /sass$/, 'scss' unless File.exists?(source_file)
					# if needs render, delete target file (force render).
					# File.delete(target_file) if force_sass_refresh?(source_file, target_file) # rescue true
				when /\.js$/
					source_file.gsub! /js$/i, 'coffee'
				end
			end
			return false unless File.exists?(source_file) && asset_needs_render?(source_file, target_file)
			# check sass / scss, coffee script
			case source_file
			when /\.scss$/, /\.sass$/
				if defined? ::Sass
					source_file, map = Sass::Engine.for_file(source_file, cache_store: @sass_cache).render_with_sourcemap(params[:assets_public])
					render_asset request, (target_file + '.map'), source_file rescue false
				else
					return false
				end
			when /\.coffee$/
				if defined? ::CoffeeScript
					source_file = CoffeeScript.compile(IO.read source_file)
				else
					return false
				end
			else
				source_file = IO.read source_file
			end
			render_asset(request, target_file, source_file)
		end

		def asset_needs_render? source_file, target_file
			return true unless Anorexic.file_exists?(target_file)
			raise 'asset verification failed - no such file?!' unless File.exists?(source_file)
			File.mtime(source_file) > Anorexic.file_mtime(target_file)
		end

		def force_sass_refresh? source_file, target_file
			return false unless File.exists?(source_file) && Anorexic.file_exists?(target_file) && defined?(::Sass)
			Sass::Engine.for_file(source_file, cache_store: @sass_cache).dependencies.each {|e| return true if File.exists?(e.options[:filename]) && (File.mtime(e.options[:filename]) > File.mtime(target_file))} # fn = File.join( e.options[:load_paths][0].root, e.options[:filename]) 
			false
		end

		# returns true if data was send
		#
		# always returns false (data wasn't sent, only saved to disk).
		def render_asset request, target, data
			Anorexic.save_file(target, data)
			false
		end

		# sends a response for an error code, rendering the relevent file (if exists).
		def send_by_code request, code, headers = {}
			begin
				if params[:root]
					if defined?(::Haml) && Anorexic.file_exists?(File.join(params[:root], "#{code}.haml"))
						return send_raw_data request, Haml::Engine.new( Anorexic.load_file( File.join( params[:root], "#{code}.haml" ) ) ).render( self, request: request), 'text/html', code, headers
					elsif defined?(::ERB) && Anorexic.file_exists?(File.join(params[:root], "#{code}.erb"))
						return send_raw_data request, ERB.new( Anorexic.load_file( File.join(params[:root], "#{code}.erb") ) ).result(binding), 'text/html', code, headers
					elsif send_file(request, File.join(params[:root], "#{code}.html"), code, headers)
						return true
					end
				end
				return true if send_raw_data(request, HTTPResponse::STATUS_CODES[code], "text/plain", code, headers)
			rescue Exception => e
				Anorexic.error e
			end
			false
		end

		def send_static_file request
			return false unless params[:root]
			file_requested = request[:path].to_s.split('/')
			unless file_requested.include? ".."
				file_requested.shift
				return true if send_file request, File.join(params[:root], *file_requested)
				return true if send_file request, File.join(params[:root], *file_requested, params[:index_file])
			end
			return false
		end

		def send_file request, filename, status_code = 200, headers = {}
			if Anorexic.file_exists?(filename) && !::File.directory?(filename)
				return send_raw_data request, Anorexic.load_file(filename), MimeTypeHelper::MIME_DICTIONARY[::File.extname(filename)], status_code, headers
			end
			return false
		end
		def send_raw_data request, data, mime, status_code = 200, headers = {}
			response = HTTPResponse.new request, status_code, headers
			response['cache-control'] = 'public, max-age=86400'					
			response << data
			response['content-length'] = data.bytesize
			response.finish
			true
		end

	end

end