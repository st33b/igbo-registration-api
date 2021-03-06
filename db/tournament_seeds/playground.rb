# frozen_string_literal: true

playground = Tournament.create!(
  name: 'Playground Tournament',
  year: 2022,
  start_date: '2022-09-03',
)

playground.config_items += [
  ConfigItem.new(
    key: 'location',
    value: 'Atlanta, GA',
  ),
  ConfigItem.new(
    key: 'entry_deadline',
    value: '2022-08-26T23:59:59-04:00',
  ),
  ConfigItem.new(
    key: 'time_zone',
    value: 'America/New_York',
  ),
  ConfigItem.new(
    key: 'image_path',
    value: '/images/generic.jpg',
  ),
  ConfigItem.new(
    key: 'team_size',
    value: 4,
  ),
  ConfigItem.new(
    key: 'website',
    value: 'http://www.igbo.org',
  ),
  ConfigItem.new(
    key: 'paypal_client_id',
    value: 'sb',
  ),
  ConfigItem.new(
    key: 'email_in_dev',
    value: 'false',
  ),
  ConfigItem.new(
    key: 'display_capacity',
    value: 'false',
  ),
]

playground.contacts << Contact.new(
  name: 'Kylie Minogue',
  email: 'director@playground.org',
  role: :director,
)
playground.contacts << Contact.new(
  name: 'Dua Lipa',
  email: 'architect@playground.org',
  role: :secretary,
)
playground.contacts << Contact.new(
  name: 'Tom Aspaul',
  email: 'musicman@playground.org',
  role: :treasurer,
)

# playground.purchasable_items += [
#   PurchasableItem.new(
#     category: :ledger,
#     determination: :entry_fee,
#     name: 'Tournament entry fee',
#     user_selectable: false,
#     value: 119,
#   ),
#   PurchasableItem.new(
#     category: :ledger,
#     determination: :early_discount,
#     name: 'Early registration discount',
#     user_selectable: false,
#     value: -19,
#     configuration: {
#       valid_until: '2022-04-14T00:00:00-04:00',
#     },
#   ),
#   PurchasableItem.new(
#     category: :ledger,
#     determination: :late_fee,
#     name: 'Late registration fee',
#     user_selectable: false,
#     value: 11,
#     configuration: {
#       applies_at: '2022-05-13T00:00:00-04:00',
#     },
#   ),
#   PurchasableItem.new(
#     category: :bowling,
#     determination: :single_use,
#     name: 'Thursday night 9-pin No-tap',
#     user_selectable: true,
#     value: 20,
#     configuration: {
#       order: 1,
#     }
#   ),
#   PurchasableItem.new(
#     category: :bowling,
#     determination: :single_use,
#     name: "Women's Optional",
#     user_selectable: true,
#     value: 20,
#     configuration: {
#       order: 2,
#     }
#   ),
#   PurchasableItem.new(
#     category: :bowling,
#     determination: :single_use,
#     name: 'Optional Scratch',
#     user_selectable: true,
#     value: 20,
#     configuration: {
#       order: 3,
#     }
#   ),
#   PurchasableItem.new(
#     category: :bowling,
#     determination: :single_use,
#     name: 'Optional Handicap',
#     user_selectable: true,
#     value: 20,
#     configuration: {
#       order: 4,
#     }
#   ),
#   PurchasableItem.new(
#     category: :bowling,
#     determination: :single_use,
#     name: 'Scratch Side Pots',
#     user_selectable: true,
#     value: 30,
#     configuration: {
#       order: 5,
#     }
#   ),
#   PurchasableItem.new(
#     category: :bowling,
#     determination: :single_use,
#     name: 'Handicap Side Pots',
#     user_selectable: true,
#     value: 30,
#     configuration: {
#       order: 6,
#     }
#   ),
#   PurchasableItem.new(
#     category: :bowling,
#     determination: :single_use,
#     name: 'Mystery Doubles',
#     user_selectable: true,
#     value: 10,
#     configuration: {
#       order: 7,
#     }
#   ),
#   PurchasableItem.new(
#     category: :bowling,
#     determination: :single_use,
#     name: 'Best 3 Across 9',
#     user_selectable: true,
#     value: 20,
#     configuration: {
#       order: 8,
#     }
#   ),
#   PurchasableItem.new(
#     category: :bowling,
#     determination: :single_use,
#     refinement: :division,
#     name: 'Scratch Masters',
#     user_selectable: true,
#     value: 50,
#     configuration: {
#       division: 'D: Dinah Shore',
#       note: '0-169',
#     },
#   ),
#   PurchasableItem.new(
#     category: :bowling,
#     determination: :single_use,
#     refinement: :division,
#     name: 'Scratch Masters',
#     user_selectable: true,
#     value: 50,
#     configuration: {
#       division: 'C: Lucille Ball',
#       note: '170-189',
#     },
#   ),
#   PurchasableItem.new(
#     category: :bowling,
#     determination: :single_use,
#     refinement: :division,
#     name: 'Scratch Masters',
#     user_selectable: true,
#     value: 60,
#     configuration: {
#       division: 'B: Bob Hope',
#       note: '190-208',
#     },
#   ),
#   PurchasableItem.new(
#     category: :bowling,
#     determination: :single_use,
#     refinement: :division,
#     name: 'Scratch Masters',
#     user_selectable: true,
#     value: 60,
#     configuration: {
#       division: 'A: Frank Sinatra',
#       note: '209+',
#     },
#   ),
#   PurchasableItem.new(
#     category: :banquet,
#     determination: :multi_use,
#     name: 'Banquet Entry (non-bowler)',
#     user_selectable: true,
#     value: 20,
#   ),
# ]

eff = ExtendedFormField.find_by(name: 'standings_link')
playground.additional_questions << AdditionalQuestion.new(
  extended_form_field: eff,
  validation_rules: eff.validation_rules,
  order: 2,
)
eff = ExtendedFormField.find_by(name: 'comment')
playground.additional_questions << AdditionalQuestion.new(
  extended_form_field: eff,
  validation_rules: eff.validation_rules,
  order: 3,
)
eff = ExtendedFormField.find_by(name: 'pronouns')
playground.additional_questions << AdditionalQuestion.new(
  extended_form_field: eff,
  validation_rules: eff.validation_rules,
  order: 1,
)
