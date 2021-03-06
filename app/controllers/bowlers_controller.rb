class BowlersController < ApplicationController
  wrap_parameters false

  ADDITIONAL_QUESTION_RESPONSES_ATTRS = %i[
      name
      response
    ]
  PERSON_ATTRS = %i[
      first_name
      last_name
      usbc_id
      igbo_id
      birth_month
      birth_day
      nickname
      phone
      email
      address1
      address2
      city
      state
      country
      postal_code
    ].freeze
  BOWLER_ATTRS = [
    :position,
    :doubles_partner_num,
    :doubles_partner_identifier,
    :shift_identifier,
    person_attributes: PERSON_ATTRS,
    additional_question_responses: ADDITIONAL_QUESTION_RESPONSES_ATTRS,
  ].freeze

  ####################################

  def index
    permit_params
    load_tournament

    unless tournament.present?
      render json: nil, status: :not_found
      return
    end

    list = parameters[:unpartnered].present? ? tournament.bowlers.without_doubles_partner : tournament.bowlers
    render json: BowlerBlueprint.render(list, view: :list), status: :ok
  end

  def create
    permit_params
    load_team
    load_tournament

    # the tournament should be loaded either by association with the team, or finding by its identifier
    unless tournament.present?
      render json: nil, status: :not_found
      return
    end

    form_data = clean_up_bowler_data(parameters.require(:bowlers))
    bowlers = []
    form_data.each do |data|
      a_bowler = bowler_from_params(data)
      unless a_bowler.valid?
        Rails.logger.info(a_bowler.errors.inspect)
        render json: a_bowler.errors, status: :unprocessable_entity
        return
      end
      bowlers << a_bowler
    end

    # now, are they joining a team, or registering solo?
    if team.present?
      # joining
      if team.bowlers.count == tournament.team_size
        render json: { message: 'This team is full.' }, status: :bad_request
        return
      end
    else
      # registering solo or doubles

    end

    bowlers.each do |b|
      b.save
      TournamentRegistration.register_bowler(b)
    end

    if bowlers.length == 2
      bowlers[0].doubles_partner = bowlers[1]
      bowlers[1].doubles_partner = bowlers[0]
      bowlers.map(&:save)
    end

    render json: BowlerBlueprint.render(bowlers), status: :created
  end

  def show
    load_bowler

    unless @bowler.present?
      render json: nil, status: :not_found
      return
    end

    result = {
      bowler: BowlerBlueprint.render_as_hash(bowler, view: :detail),
      available_items: rendered_purchasable_items_by_identifier,
    }
    render json: result, status: :ok
  end

  def purchase_details
    # receive:
    # - bowler ID via params
    # - purchasable item IDs via request body
    # - unpaid purchase IDs via request body (return error if we think they're paid)
    # - expected total via request body (so we can proactively prevent purchase if we reach a different total,
    #  e.g., if they got the early discount upon registration but the date passed before they paid)
    #  ---- is that a thing we should enforce? survey directors to see what they think, add it later if they want it
    #
    # identifier: ... (bowler identifier)
    # purchase_identifiers: [],
    # purchasable_items: [
    #   {
    #     identifier: ...,
    #     quantity: X,
    #   },
    #   ...
    # ],
    # expected_total:
    #
    # return:
    #   - client ID (paypal identifier for tournament)
    #   - total to charge

    load_bowler
    unless bowler.present?
      render json: { error: 'Bowler not found' }, status: :not_found
      return
    end

    # permit and parse params (quantities come in as strings)
    params.permit!
    details = params.to_h
    details[:expected_total] = details[:expected_total].to_i
    details[:purchasable_items]&.each_index do |index|
      details[:purchasable_items][index][:quantity] = details[:purchasable_items][index][:quantity].to_i
    end

    # validate required ledger items (entry fee, early discount, late fee)
    purchase_identifiers = details[:purchase_identifiers] || []
    matching_purchases = bowler.purchases.unpaid.where(identifier: purchase_identifiers)
    unless purchase_identifiers.count == matching_purchases.count
      render json: { error: 'Mismatched unpaid purchases count' }, status: :precondition_failed
      return
    end
    purchases_total = matching_purchases.sum(&:amount)

    # gather purchasable items
    items = details[:purchasable_items] || []
    identifiers = items.collect { |i| i[:identifier] }
    purchasable_items = tournament.purchasable_items.where(identifier: identifiers).index_by(&:identifier)

    # does the number of items found match the number of identifiers passed in?
    unless identifiers.count == purchasable_items.count
      render json: { error: 'Mismatched number of purchasable item identifiers' }, status: :not_found
      return
    end

    # are we purchasing any single-use items that have been purchased previously?
    matching_previous_single_item_purchases = PurchasableItem.single_use.joins(:purchases)
                                                             .where(identifier: identifiers)
                                                             .where(purchases: { bowler_id: bowler.id })
                                                             .where.not(purchases: { paid_at: nil })
    unless matching_previous_single_item_purchases.empty?
      render json: { error: 'Attempting to purchase previously-purchased single-use item(s)' }, status: :precondition_failed
      return
    end

    # are we purchasing more than one of anything?
    multiples = items.filter { |i| i[:quantity] > 1 }
    # make sure they're all multi-use
    multiples.filter! do |i|
      identifier = i[:identifier]
      item = purchasable_items[identifier]
      !item.multi_use?
    end
    unless multiples.empty?
      render json: { error: 'Cannot purchase multiple instances of single-use items.'}, status: :unprocessable_entity
      return
    end

    # apply any relevant event bundle discounts
    bundle_discount_items = tournament.purchasable_items.bundle_discount
    previous_paid_event_item_identifiers = bowler.purchases.event.paid.map { |p| p.purchasable_item.identifier }
    applicable_discounts = bundle_discount_items.select do |discount|
      (identifiers + previous_paid_event_item_identifiers).intersection(discount.configuration['events']).length == discount.configuration['events'].length
    end
    total_discount = applicable_discounts.sum(&:value)

    # apply any relevant event-linked late fees
    late_fee_items = tournament.purchasable_items.event_linked.late_fee
    applicable_fees = late_fee_items.select do |fee|
      identifiers.include?(fee.configuration['event']) && tournament.in_late_registration?(event_linked_late_fee: fee)
    end
    total_fees = applicable_fees.sum(&:value)

    # items_total = purchasable_items.sum(&:value)
    items_total = items.map do |item|
      identifier = item[:identifier]
      quantity = item[:quantity]
      purchasable_items[identifier].value * quantity
    end.sum

    # sum up the total of unpaid purchases and indicated purchasable items
    total_to_charge = purchases_total + items_total + total_discount + total_fees

    # Disallow a purchase if there's nothing owed
    if (total_to_charge == 0)
      render json: { error: 'Total to charge is zero' }, status: :precondition_failed
      return
    end

    # build response with client ID and total to charge
    output = {
      total: total_to_charge,
      paypal_client_id: tournament.paypal_client_id,
    }

    render json: output, status: :ok
  end

  private

  attr_reader :tournament, :team, :bowler, :parameters

  def permit_params
    @parameters = params.permit(:identifier, :team_identifier, :tournament_identifier, :unpartnered, bowlers: BOWLER_ATTRS)
  end

  def load_bowler
    identifier = params.require(:identifier)
    @bowler = Bowler.includes(:tournament, :person, :ledger_entries, :team, { purchases: [:purchasable_item] })
                    .where(identifier: identifier)
                    .first
    @tournament = bowler&.tournament
    @team = bowler&.team
  end

  def load_team
    identifier = parameters[:team_identifier]
    if identifier.present?
      @team = Team.find_by_identifier(identifier)
      @tournament = team&.tournament
    end
  end

  def load_tournament
    return unless tournament.nil?
    identifier = parameters[:tournament_identifier]
    if identifier.present?
      @tournament = Tournament.includes(:bowlers).find_by_identifier(identifier)
    end
  end

  def rendered_purchasable_items_by_identifier
    excluded_item_names = (bowler.purchases.single_use + bowler.purchases.event).collect { |p| p.purchasable_item.name }
    items = tournament.purchasable_items.user_selectable.where.not(name: excluded_item_names)
    items.each_with_object({}) { |i, result| result[i.identifier] = PurchasableItemBlueprint.render_as_hash(i) }
  end

  def clean_up_bowler_data(permitted_params)
    permitted_params.each do |p|
      # Remove any empty person attributes
      p['person_attributes'].delete_if { |_k, v| v.length.zero? }

      # Person attributes: Convert integer params from string to integer
      %w[birth_month birth_day].each do |attr|
        p['person_attributes'][attr] = p['person_attributes'][attr].to_i
      end

      # Remove additional question responses that are empty
      p['additional_question_responses'].filter! { |r| r['response'].present? }

      # transform the add'l question responses into the shape that we can accept via ActiveRecord
      p['additional_question_responses_attributes'] =
        additional_question_responses(p['additional_question_responses'])

      # remove that key from the params...
      p.delete('additional_question_responses')

      # If we've specified a doubles partner, then look them up by identifier and put their id in the params
      if p['doubles_partner_identifier'].present?
        partner = Bowler.where(identifier: p['doubles_partner_identifier'], doubles_partner_id: nil).first
        p['doubles_partner_id'] = partner.id unless partner.nil?
        p.delete('doubles_partner_identifier')
      end

      if p['shift_identifier'].present?
        shift = Shift.find_by(identifier: p['shift_identifier'])
        p['bowler_shift_attributes'] = { shift_id: shift.id } unless shift.nil?
        p.delete('shift_identifier')
      end
    end

    permitted_params
  end

  # These are used only when adding a bowler to an existing team

  def bowler_from_params(info)
    bowler = Bowler.new(info.merge(team: team, tournament: tournament))
    if team.present?
      partner = team.bowlers.without_doubles_partner.first
      bowler.doubles_partner = partner if partner.present?
    end
    bowler
  end

  def additional_question_responses(params)
    params.each_with_object([]) do |response_param, collected|
      collected << {
        response: response_param['response'],
        extended_form_field_id: extended_form_fields[response_param['name']].id,
      }
    end
  end

  def extended_form_fields
    @extended_form_fields ||= ExtendedFormField.all.index_by(&:name)
  end
end
