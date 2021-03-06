require 'test_helper'

class LinksControllerTest < ActionController::TestCase
	include Devise::TestHelpers
	
	setup do
		@link = links(:alice_facebook)
		@user = @link.user
	end
	
	def current_user
		warden.session_serializer.fetch :user
	end

	test "should get index" do
		sign_in @user
		get :index
		assert_response :success
		assert_not_nil assigns(:links)
	end

	test "should redirect for index when logged out" do
		get :index
		assert_redirected_to new_user_session_path
	end
	
	test 'should not find new' do
		assert_raises ActionController::UrlGenerationError do
			get :new
		end
	end
	
	test 'should not find edit' do
		assert_raises ActionController::UrlGenerationError do
			get :edit, id: @link.id
		end
	end
	
	test "should create new link for signed in user" do
		@request.env['omniauth.auth'] =
		{
			'provider' => 'MyProvider',
			'uid' => 'MyID',
			'info' => { 'email' => @user.email },
			'credentials' => {
				'expires_at' => 2.days.from_now.to_s,
				'token' => 'MyToken',
				'secret' => 'MySecret'
			}
		}
		sign_in @user
	 	assert_difference('Link.count') do
	 		post :create
	 	end
	 
	 	assert_redirected_to settings_path+'#accounts'
	end
	
	test "should refresh link for signed in user" do
		@request.env['omniauth.auth'] =
		{
			'provider' => @link.provider,
			'uid' => @link.uid,
			'credentials' => {
				'expires_at' => 2.days.from_now.to_s,
				'token' => 'MyNewToken',
				'secret' => 'MySecret'
			}
		}
		sign_in @user
	 	assert_no_difference('Link.count') do
	 		post :create
	 	end
	 
		assert_equal 'MyNewToken', Link.find(@link.id).access_token, "Didn't update token"
	end
	
	test "should create new for existing user" do
		@request.env['omniauth.auth'] =
		{
			'provider' => 'MyProvider',
			'uid' => 'MyID',
			'info' => { 'email' => @user.email },
			'credentials' => {
				'expires_at' => 2.days.from_now.to_s,
				'token' => 'MyToken',
				'secret' => 'MySecret'
			}
		}
	 	assert_difference('Link.count') do
	 		post :create
	 	end
	
		assert_equal @user.id, current_user.id, "Didn't sign in"
	end
	
	test "should create new link and new user" do
		@request.env['omniauth.auth'] =
		{
			'provider' => 'MyProvider',
			'uid' => 'MyID',
			'info' => { 'email' => 'my@mail.com' },
			'credentials' => {
				'expires_at' => 2.days.from_now.to_s,
				'token' => 'MyToken',
				'secret' => 'MySecret'
			}
		}
	 	assert_difference('Link.count') do
		assert_difference('User.count') do
	 		post :create
	 	end
		end
		
		assert_equal 'my@mail.com', User.last.email
		assert_equal User.last.id, current_user.id, "Didn't sign in"
	end
	
	test 'should forbid creating link via api' do
	 	post :create, format: :json
	 	assert_response :forbidden
	end
	 
	test "should show link" do
		sign_in @user
	 	get :show, id: @link.id
	 	assert_response :success
	end
	
	test "should update link" do
		sign_in @user
	 	do_share = @link.do_share
	 	patch :update, id: @link.id, link: { do_share: !do_share }
	 	assert_redirected_to settings_path + '#accounts'
	 	assert_equal !do_share, Link.find(@link.id).do_share, "Setting wasn't changed"
	end
	 
	test "should destroy link" do
		sign_in @user
	 	assert_difference('Link.count', -1) do
	 		delete :destroy, id: @link
	 	end
	 
	 	assert_redirected_to settings_path + '#accounts'
	end
end
