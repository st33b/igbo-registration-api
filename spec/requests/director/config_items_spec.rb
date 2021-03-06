require 'rails_helper'
require 'devise/jwt/test_helpers'

describe Director::ConfigItemsController, type: :request do
  let(:requesting_user) { create(:user, :superuser) }
  let(:headers) do
    {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    }
  end
  let(:auth_headers) { Devise::JWT::TestHelpers.auth_headers(headers, requesting_user) }

  describe '#update' do
    subject { patch uri, headers: auth_headers, params: params, as: :json }

    let(:uri) { "/director/config_items/#{config_item_id}" }

    let(:tournament_identifier) { tournament.identifier }
    let(:tournament) { create :tournament }
    let(:config_item) { create :config_item, :location, tournament: tournament }
    let(:config_item_id) { config_item.id }

    let(:params) do
      {
        config_item: {
          value: 'Anchorage, AK',
        }
      }
    end

    include_examples 'an authorized action'

    it 'succeeds with a 200 OK' do
      subject
      expect(response).to have_http_status(:ok)
    end

    context 'an active tournament' do
      let(:tournament) { create :tournament, :active }

      it 'prevents updates' do
        subject
        expect(response).to have_http_status(:forbidden)
      end

      context 'unless the item is allowed to be changed while the tournament is active' do
        let(:config_item) { create :config_item, :location, tournament: tournament, key: 'display_capacity' }
        let(:params) do
          {
            config_item: {
              value: true,
            }
          }
        end

        it 'succeeds with a 200 OK' do
          subject
          expect(response).to have_http_status(:ok)
        end

      end
    end

    context 'as an unpermitted user' do
      let(:requesting_user) { create(:user, :unpermitted) }

      it 'shall not pass' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'as a director' do
      let(:requesting_user) { create(:user, :director) }

      it 'shall not pass' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end

      context 'associated with this tournament' do
        let(:requesting_user) { create :user, :director, tournaments: [tournament] }

        it 'shall pass' do
          subject
          expect(response).to have_http_status(:ok)
        end
      end
    end

    context 'error scenarios' do
      context 'an unrecognized config item id' do
        let(:config_item_id) { 'say-what-now' }

        it 'yields a 404 Not Found' do
          subject
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

end
