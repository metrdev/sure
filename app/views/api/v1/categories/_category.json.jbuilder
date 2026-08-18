# frozen_string_literal: true

json.id category.id
json.name category.name
json.color category.color
json.icon category.lucide_icon
json.sharing_mode category.effective_sharing_mode
json.sharing_started_on category.effective_sharing_started_on if category.shared?

# Parent information (for subcategories)
if category.parent.present?
  json.parent do
    json.id category.parent.id
    json.name category.parent.name
  end
else
  json.parent nil
end

# Subcategories count (for parent categories)
json.subcategories_count Category.visible_to(viewer).where(parent_id: category.id).count

json.created_at category.created_at.iso8601
json.updated_at category.updated_at.iso8601
