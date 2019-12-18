# frozen_string_literal: true

class ProductResearchSafetyCertificationRequirement < ApplicationRecord

  acts_as_paranoid # soft-delete functionality

  belongs_to :product
  belongs_to :research_safety_certificate

  validates :product, presence: true
  validates :research_safety_certificate, presence: true
  validates :research_safety_certificate, uniqueness: { scope: [:deleted_at, :product_id] }

end
