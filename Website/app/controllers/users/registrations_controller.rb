# -*- encoding : utf-8 -*-
# The business logic for registrations of accounts.
#
# This code is part of the Stoffi Music Player Project.
# Visit our website at: stoffiplayer.com
#
# Author::		Christoffer Brodd-Reijer (christoffer@stoffiplayer.com)
# Copyright::	Copyright (c) 2013 Simplare
# License::		GNU General Public License (stoffiplayer.com/license)

class Users::RegistrationsController < Devise::RegistrationsController
	before_filter :get_profile_id, only: [ :show, :playlists ]

	oauthenticate except: [ :new, :create, :show ]

	def new
		if request.referer && ![user_session_url, user_registration_url, user_unlock_url, user_password_url].index(request.referer)
			session["user_return_to"] = request.referer
		end
		build_resource {}
		render '/users/sessions/new', layout: 'fullwidth'
	end
	
	def create
		if verify_recaptcha
			flash[:alert] = nil
			build_resource(sign_up_params)

			if resource.save
				yield resource if block_given?
				if resource.active_for_authentication?
					set_flash_message :notice, :signed_up if is_flashing_format?
					sign_up(resource_name, resource)
					respond_with resource, location: after_sign_up_path_for(resource)
				else
					set_flash_message :notice, :"signed_up_but_#{resource.inactive_message}" if is_flashing_format?
					expire_data_after_sign_in!
					respond_with resource, location: after_inactive_sign_up_path_for(resource)
				end
			else
				clean_up_passwords resource
				render '/users/sessions/new', layout: 'fullwidth'
			end
		else
			build_resource
			clean_up_passwords(resource)
			flash.now[:alert] = t("activerecord.errors.messages.human")
			flash.delete :recaptcha_error
			render '/users/sessions/new', layout: 'fullwidth'
		end
	end
	
	def dashboard
		@title = t "dashboard.title"
		@description = t "dashboard.description"
		
		@donations = current_user.donations.order('created_at DESC').limit(5)
		@artists = Artist.top(for: current_user).limit 10
		@songs = Song.top(for: current_user).limit 10
		@listens = current_user.listens.order('created_at DESC').limit(10)
		@devices = current_user.devices.order('updated_at DESC')
		@playlists = current_user.playlists.order(:name)
		
		@configuration = current_user.configurations.first
		
		render layout: (params[:format] == 'embedded' ? 'empty' : true)
	end
	
	def edit
		prepare_settings
	
		respond_to do |format|
			format.html { render action: "edit" }
			format.embedded { render action: "dashboard" }
		end
	end
	
	def update
		@user = User.find(current_user.id)
		
		require_password = params[:edit_password] != nil
		unless require_password
			params[:user].delete :password
			params[:user].delete :password_confirmation
		end
		
		success = if require_password
			@user.update_with_password resource_params
		else
			params[:user].delete :current_password
			@user.update_without_password resource_params
		end
		
		if success
			sign_in @user, bypass: true
			redirect_to after_update_path_for(@user)
		else
			prepare_settings
			render 'edit'
		end
	end
	
	def show
		@user = User.find(params[:id])
		
		name = d(@user.name)
		@title = name.titleize
		@description = t "profile.description", usernames: name.possessive
		@channels = ["user_#{@user.id}"]
		
		@donations = @user.donations.order('created_at DESC').limit(5)
		@artists = Artist.top(for: @user).limit 10
		@songs = Song.top(for: @user).limit 10
		@listens = @user.listens.order('created_at DESC').limit(10)
		@playlists = @user.playlists.where(
			current_user == @user ? "":"is_public = 1"
			).order(:name)
			
		@meta_tags =
		[
			{ property: "og:title", content: name },
			{ property: "og:type", content: "profile" },
			{ property: "og:image", content: @user.picture },
			{ property: "og:url", content: profile_url(@user) },
			{ property: "og:description", content: @description },
			{ property: "og:site_name", content: "Stoffi" },
			{ property: "fb:app_id", content: "243125052401100" },
		]
		
		# name
		if name.index " "
			fullname = name.split(" ",2) # can we do better split than this?
			@meta_tags << { property: "profile:first_name", content: fullname[0] }
			@meta_tags << { property: "profile:last_name", content: fullname[1] }
		else
			@meta_tags << { property: "profile:username", content: name }
		end
		
		# encrypted uid
		e_fb_uid = @user.encrypted_uid('facebook')
		if e_fb_uid != nil
			@meta_tags << { property: "fb:profile_id", content: e_fb_uid }
		end
		
		respond_to do |format|
			format.html { render }
			format.mobile { render }
			format.embedded { render }
			format.xml { render xml: @user, include: :links }
			format.json { render json: @user, include: :links }
		end
	end
	
	def destroy
		session["user_return_to"] = request.referer
		SyncController.send('delete', @current_user, request)
		resource.destroy
		set_flash_message :notice, :destroyed
		sign_out_and_redirect(self.resource)
	end
	
	protected
	
	def after_update_path_for(resource)
		settings_path
	end
	
	private
	
	def resource_params
		params.require(:user).permit(:email, :password, :password_confirmation, :current_password, :image, :name_source, :custom_name, :show_ads)
	end
	
	def get_profile_id
		params[:id] = process_me(params[:id])
	end
	
	def prepare_settings
		
		@new_links = Array.new
		Link.available.each do |link|
			n = link[:name]
			ln = link[:link_name] || n.downcase
			if current_user.links.find_by(provider: ln) == nil
				img = "auth/#{n.downcase}_14_white"
				title = t("auth.link", service: n)
				path = "/auth/#{ln}"
				@new_links <<
				{
					name: n,
					img: img,
					title: title,
					path: path
				}
			end
		end
		
	end
end
