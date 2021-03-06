require 'rails_helper'
require 'devise/jwt/test_helpers'

describe Director::BowlersController, type: :request do
  let(:requesting_user) { create(:user, :superuser) }
  let(:headers) do
    {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    }
  end
  let(:auth_headers) { Devise::JWT::TestHelpers.auth_headers(headers, requesting_user) }

  describe '#index' do
    subject { get uri, headers: auth_headers }

    let(:uri) { "/director/tournaments/#{tournament_identifier}/bowlers" }

    let(:tournament_identifier) { tournament.identifier }
    let(:tournament) { create :tournament, :active }

    before do
      10.times do
        create :bowler, tournament: tournament, team: create(:team, tournament: tournament)
      end
    end

    include_examples 'an authorized action'

    it 'returns an array' do
      subject
      expect(json).to be_instance_of(Array);
    end

    it 'includes all registered bowlers in the response' do
      subject
      expect(json.length).to eq(10);
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
      context 'an unrecognized tournament identifier' do
        let(:tournament_identifier) { 'say-what-now' }

        it 'yields a 404 Not Found' do
          subject
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe '#show' do
    subject { get uri, headers: auth_headers }

    let(:uri) { "/director/bowlers/#{bowler_identifier}" }

    let(:tournament) { create :tournament }
    let(:bowler) { create :bowler, tournament: tournament, team: create(:team, tournament: tournament) }
    let(:bowler_identifier) { bowler.identifier }

    include_examples 'an authorized action'

    it 'returns a 200 OK' do
      subject
      expect(response).to have_http_status(:ok)
    end

    it 'returns a JSON representation of the bowler' do
      subject
      expect(json['identifier']).to eq(bowler.identifier);
    end

    context 'When I am an unpermitted user' do
      let(:requesting_user) { create(:user, :unpermitted) }

      it 'yields a 401 Unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'When I am a tournament director' do
      let(:requesting_user) { create(:user, :director, tournaments: my_tournaments) }
      let(:my_tournaments) { [] }

      it 'yields a 401 Unauthorized' do
        subject
        expect(response).to have_http_status(:unauthorized)
      end

      context 'for this tournament' do
        let(:my_tournaments) { [tournament] }

        it 'yields a 200 OK' do
          subject
          expect(response).to have_http_status(:ok)
        end

        it 'returns a JSON representation of the bowler' do
          subject
          expect(json['identifier']).to eq(bowler.identifier);
        end
      end
    end
  end

  describe '#destroy' do
    subject { delete uri, headers: auth_headers, as: :json }

    let(:uri) { "/director/bowlers/#{bowler_identifier}" }

    let(:tournament) { create :tournament, :active }
    let(:bowler) { create :bowler, tournament: tournament }
    let(:bowler_identifier) { bowler.identifier }

    include_examples 'an authorized action'

    it 'succeeds with a 204 No Content' do
      subject
      expect(response).to have_http_status(:no_content)
    end

    context 'on a shift' do
      let(:shift) { create :shift, :high_demand, tournament: tournament }
      let!(:bowler_shift) { create :bowler_shift, bowler: bowler, shift: shift }

      it "drops the requested count of the shift" do
        expect { subject }.to change { shift.reload.requested }.by(-1)
      end

      it "doesn't change the confirmed count of the shift" do
        expect { subject }.not_to change { shift.reload.confirmed }
      end

      context 'when the bowler is confirmed in the shift' do
        let!(:bowler_shift) { create :bowler_shift, :confirmed, bowler: bowler, shift: shift }

        it "drops the confirmed count of the shift" do
          expect { subject }.to change { shift.reload.confirmed }.by(-1)
        end

        it "doesn't change the requested count of the shift" do
          expect { subject }.not_to change { shift.reload.requested }
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
          expect(response).to have_http_status(:no_content)
        end
      end
    end

    context 'error scenarios' do
      context 'an unrecognized team identifier' do
        let(:bowler_identifier) { 'say-what-now' }

        it 'yields a 404 Not Found' do
          subject
          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe '#update' do
    subject { patch uri, headers: auth_headers, params: params, as: :json }

    let(:uri) { "/director/bowlers/#{bowler_identifier}" }

    let(:tournament) { create :tournament, :active }
    let(:team) { create :team, name: 'Ladies Who Lunch', tournament: tournament }
    let(:bowler) { create :bowler, tournament: tournament, team: team }
    let(:bowler_identifier) { bowler.identifier }
    let(:person_attributes) { { nickname: 'Freddy' } }
    let(:team_params) { {} }
    let(:additional_question_response_params) { {} }
    let(:verified_data_params) { {} }
    let(:params) do
      {
        bowler: {
          person_attributes: person_attributes,
          team: team_params,
          additional_question_responses: additional_question_response_params,
          verified_data: verified_data_params,
        },
      }
    end

    include_examples 'an authorized action'

    it 'succeeds with a 200 OK' do
      subject
      expect(response).to have_http_status(:ok)
    end

    it 'includes the updated bowler in the response' do
      subject
      expect(json).to have_key('last_name')
      expect(json).to have_key('identifier')
      expect(json['nickname']).to eq('Freddy')
    end

    it 'does not change their team' do
      subject
      expect(json['team']['name']).to eq('Ladies Who Lunch')
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

    context 'moving the bowler to a different team' do
      let(:new_team) { create :team, name: 'Dudes Who Dance', tournament: tournament }
      let(:team_params) { { identifier: new_team.identifier } }

      it 'succeeds with a 200 OK' do
        subject
        expect(response).to have_http_status(:ok)
      end

      it 'includes the updated bowler in the response' do
        subject
        expect(json).to have_key('identifier')
      end

      it 'reflects the new team' do
        subject
        expect(json['team']['name']).to eq('Dudes Who Dance')
      end

      context 'without supplying person_attributes' do
        let(:params) do
          {
            bowler: {
              team: team_params,
            },
          }
        end

        it 'succeeds with a 200 OK' do
          subject
          expect(response).to have_http_status(:ok)
        end

        it 'reflects the new team' do
          subject
          expect(json['team']['name']).to eq('Dudes Who Dance')
        end
      end
    end

    context 'updating an additional question response' do
      let(:aq) do
        create(:additional_question,
               extended_form_field: create(:extended_form_field, :standings_link),
               tournament: tournament)
      end
      let(:additional_question_response_params) do
        [
          {
            name: aq.name,
            response: 'my updated response',
          }
        ]
      end

      before do
        create :additional_question_response,
               response: 'my response',
               extended_form_field: aq.extended_form_field,
               bowler: bowler
      end

      it 'succeeds with a 200 OK' do
        subject
        expect(response).to have_http_status(:ok)
      end

      it 'includes the updated bowler in the response' do
        subject
        expect(json).to have_key('identifier')
      end

      it 'reflects the response' do
        subject
        expect(json).to have_key('additional_question_responses')
        expect(json['additional_question_responses'][aq.name]['response']).to eq('my updated response')
      end
    end

    context 'updating verified data' do
      let(:verified_data_params) do
        {
          verified_average: 199,
          handicap: 17,
          igbo_member: true,
        }
      end

      it 'succeeds with a 200 OK' do
        subject
        expect(response).to have_http_status(:ok)
      end

      it 'includes the updated bowler in the response' do
        subject
        expect(json).to have_key('identifier')
      end

      it 'reflects the response' do
        subject
        expect(json).to have_key('verified_average')
        expect(json['verified_average']).to eq(199)
      end

      it 'includes the igbo_member property' do
        subject
        expect(json).to have_key('igbo_member')
        expect(json['igbo_member']).to eq(true)
      end
    end

    context 'error scenarios' do
      context 'an unrecognized bowler identifier' do
        let(:bowler_identifier) { 'say-what-now' }

        it 'yields a 404 Not Found' do
          subject
          expect(response).to have_http_status(:not_found)
        end
      end

      context 'an unknown additional question' do
        let(:additional_question_response_params) do
          [
            {
              name: 'unknown-form-field',
              response: 'my detailed response to it',
            }
          ]
        end

        it 'yields a 400 Bad Request' do
          subject
          expect(response).to have_http_status(:bad_request)
        end

        it 'puts the validation errors into the response' do
          subject
          expect(json).to have_key('error')
        end
      end

      context 'a failed validation' do
        context 'missing a required value' do
          let(:person_attributes) { { last_name: '' } }

          it 'yields a 400 Bad Request' do
            subject
            expect(response).to have_http_status(:bad_request)
          end

          it 'puts the validation errors into the response' do
            subject
            expect(json).to have_key('error')
          end
        end
      end

      context 'moving the bowler to an unrecognized team' do
        let(:team_params) { { identifier: 'you-shall-not-pass' } }

        it 'yields a 400 Bad Request' do
          subject
          expect(response).to have_http_status(:bad_request)
        end

        it "does not change the bowler's team" do
          subject
          expect(bowler.team.reload.identifier).to eq(team.identifier)
        end
      end

      context 'moving the bowler to a full team' do
        let(:new_team) { create :team, :standard_full_team, tournament: tournament }
        let(:team_params) { { identifier: new_team.identifier } }

        it 'yields a 400 Bad Redquest' do
          subject
          expect(response).to have_http_status(:bad_request)
        end

        it "does not change the bowler's team" do
          subject
          expect(bowler.team.reload.identifier).to eq(team.identifier)
        end
      end
    end
  end

  describe '#resend_email' do
    subject { post uri, headers: auth_headers, params: params, as: :json }

    let(:uri) { "/director/bowlers/#{bowler_identifier}/resend_email" }

    let(:tournament) { create :tournament, :active }
    let(:recipient_email) { 'the_bowler@the.correct.domain' }
    let(:bowler) { create :bowler, tournament: tournament, person: create(:person, email: recipient_email) }
    let(:bowler_identifier) { bowler.identifier }

    let(:email_type) { 'registration' }
    let(:order) { nil }

    let(:params) do
      {
        type: email_type,
        order_identifier: order&.identifier,
      }
    end

    include_examples 'an authorized action'

    it 'Succeeds with No Content' do
      subject
      expect(response).to have_http_status(:no_content)
    end

    it 'sends a confirmation email' do
      expect(TournamentRegistration).to receive(:send_confirmation_email).with(bowler)
      subject
    end

    context 'a payment receipt email' do
      let(:email_type) { 'payment_receipt' }
      let(:order) { create :paypal_order }

      it 'sends a receipt email' do
        expect(TournamentRegistration).to receive(:send_receipt_email).with(bowler, order.identifier)
        subject
      end
    end
  end
end
