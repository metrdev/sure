require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  def setup
    @family = families(:dylan_family)
  end

  test "replacing and destroying" do
    transactions = categories(:food_and_drink).transactions.to_a

    categories(:food_and_drink).replace_and_destroy!(categories(:income))

    assert_equal categories(:income), transactions.map { |t| t.reload.category }.uniq.first
  end

  test "replacing with nil should nullify the category" do
    transactions = categories(:food_and_drink).transactions.to_a

    categories(:food_and_drink).replace_and_destroy!(nil)

    assert_nil transactions.map { |t| t.reload.category }.uniq.first
  end

  test "destroying parent category preserves subcategory transaction assignments" do
    parent = @family.categories.create!(
      name: "Parent With Child Transactions",
      color: "#000000",
      lucide_icon: "folder"
    )
    subcategory = @family.categories.create!(
      name: "Child With Transactions",
      color: "#111111",
      lucide_icon: "folder",
      parent: parent
    )
    transaction = Transaction.create!(category: subcategory)

    assert_difference "Category.count", -1 do
      parent.destroy!
    end

    assert_nil subcategory.reload.parent_id
    assert_equal subcategory, transaction.reload.category
  end

  test "invalid parent_id does not raise during validation" do
    category = Category.new(
      name: "Orphan Subcategory",
      color: "#000000",
      lucide_icon: "folder",
      family: @family,
      parent_id: SecureRandom.uuid
    )

    assert_nothing_raised { category.valid? }
    assert_not category.subcategory?
    assert_nil category.parent
  end

  test "subcategory can only be one level deep" do
    category = categories(:subcategory)

    error = assert_raises(ActiveRecord::RecordInvalid) do
      category.subcategories.create!(name: "Invalid category", family: @family)
    end

    assert_equal "Validation failed: Parent can't have more than 2 levels of subcategories", error.message
  end

  test "all_investment_contributions_names returns all locale variants" do
    names = Category.all_investment_contributions_names

    assert_includes names, "Investment Contributions"  # English
    assert_includes names, "Contributions aux investissements"  # French
    assert_includes names, "Investeringsbijdragen"  # Dutch
    assert names.all? { |name| name.is_a?(String) }
    assert_equal names, names.uniq  # No duplicates
  end

  test "display_name localizes default category names" do
    I18n.with_locale(:"zh-CN") do
      assert_equal "餐饮", categories(:food_and_drink).display_name
      assert_equal "未分类", Category.uncategorized.display_name
    end
  end

  test "display_name returns default category names in english" do
    I18n.with_locale(:en) do
      assert_equal "Food & Drink", categories(:food_and_drink).display_name
      assert_equal "Uncategorized", Category.uncategorized.display_name
    end
  end

  test "display_name preserves custom category names" do
    category = Category.new(name: "School Supplies", color: "#123456", lucide_icon: "book", family: @family)

    I18n.with_locale(:"zh-CN") do
      assert_equal "School Supplies", category.display_name
    end
  end

  test "display_name_with_parent localizes default parent and child names" do
    category = Category.new(
      name: "Groceries",
      color: "#123456",
      lucide_icon: "shopping-bag",
      family: @family,
      parent: categories(:food_and_drink)
    )

    I18n.with_locale(:"zh-CN") do
      assert_equal "餐饮 > 杂货", category.display_name_with_parent
    end
  end

  test "display_name_with_parent preserves custom child names" do
    category = Category.new(
      name: "Coffee Beans",
      color: "#123456",
      lucide_icon: "coffee",
      family: @family,
      parent: categories(:food_and_drink)
    )

    I18n.with_locale(:"zh-CN") do
      assert_equal "餐饮 > Coffee Beans", category.display_name_with_parent
    end
  end

  test "should accept valid 6-digit hex colors" do
    [ "#FFFFFF", "#000000", "#123456", "#ABCDEF", "#abcdef" ].each do |color|
      category = Category.new(name: "Category #{color}", color: color, lucide_icon: "shapes", family: @family)
      assert category.valid?, "#{color} should be valid"
    end
  end

  test "should reject invalid colors" do
    [ "invalid", "#123", "#1234567", "#GGGGGG", "red", "ffffff", "#ffff", "" ].each do |color|
      category = Category.new(name: "Category #{color}", color: color, lucide_icon: "shapes", family: @family)
      assert_not category.valid?, "#{color} should be invalid"
      assert_includes category.errors[:color], "is invalid"
    end
  end

  test "ids_with_transactions returns a lookup hash for categorized transactions" do
    category = categories(:food_and_drink)
    transaction = Transaction.create!(category: category)
    Entry.create!(
      account: accounts(:depository),
      entryable: transaction,
      name: "Lookup transaction",
      date: Date.current,
      amount: 10,
      currency: "USD"
    )

    lookup = Category.ids_with_transactions(family: @family, category_ids: [ category.id, 0 ])

    assert lookup.key?(category.id)
    assert_not lookup.key?(0)
  end

  test "subcategory inherits household mode and sharing date" do
    parent = @family.categories.create!(
      name: "Shared household parent",
      color: "#123456",
      lucide_icon: "home",
      sharing_mode: "shared",
      sharing_started_on: Date.new(2026, 1, 15)
    )
    child = @family.categories.create!(
      name: "Inherited household child",
      color: "#123456",
      lucide_icon: "home",
      parent: parent,
      sharing_mode: nil
    )

    assert child.shared?
    assert_equal Date.new(2026, 1, 15), child.effective_sharing_started_on
  end

  test "private categories are visible only to their owner" do
    admin = users(:family_admin)
    member = users(:family_member)
    private_category = @family.categories.create!(
      name: "Admin private category",
      color: "#123456",
      lucide_icon: "lock",
      sharing_mode: "private",
      owner: admin
    )

    assert_includes @family.categories.visible_to(admin), private_category
    assert_not_includes @family.categories.visible_to(member), private_category
    assert_not_includes @family.categories.household, private_category
  end

  test "different users can use the same private category name" do
    admin = users(:family_admin)
    member = users(:family_member)

    assert @family.categories.create!(
      name: "Personal hobbies",
      color: "#123456",
      lucide_icon: "gamepad-2",
      sharing_mode: "private",
      owner: admin
    )
    assert @family.categories.create!(
      name: "Personal hobbies",
      color: "#654321",
      lucide_icon: "music",
      sharing_mode: "private",
      owner: member
    )
  end

  test "private and household namespaces can use the same category name" do
    admin = users(:family_admin)

    assert @family.categories.create!(
      name: "Household and private duplicate",
      color: "#123456",
      lucide_icon: "users",
      sharing_mode: "aligned"
    )
    assert @family.categories.create!(
      name: "Household and private duplicate",
      color: "#654321",
      lucide_icon: "lock",
      sharing_mode: "private",
      owner: admin
    )
  end

  test "shared category becomes per-member private copies and archives its household limit" do
    admin = users(:family_admin)
    member = users(:family_member)
    category = @family.categories.create!(
      name: "Shared category to privatize",
      color: "#123456",
      lucide_icon: "shopping-bag",
      sharing_mode: "shared",
      sharing_started_on: Date.current.beginning_of_month
    )
    admin_transaction = accounts(:depository).entries.create!(
      name: "Admin shared purchase",
      date: Date.current,
      amount: 100,
      currency: @family.currency,
      entryable: Transaction.new(category: category)
    ).transaction
    member_account = @family.accounts.create!(
      owner: member,
      name: "Member private account for category transition",
      balance: 0,
      currency: @family.currency,
      accountable: Depository.new
    )
    member_transaction = member_account.entries.create!(
      name: "Member shared purchase",
      date: Date.current,
      amount: 200,
      currency: @family.currency,
      entryable: Transaction.new(category: category)
    ).transaction
    household_budget = Budget.find_or_bootstrap(@family, start_date: Date.current)
    household_limit = household_budget.budget_categories.find_by!(category: category)
    household_limit.update!(budgeted_spending: 30_000)

    admin_copy = Category::ChangeSharingMode.call!(
      category: category,
      attributes: { sharing_mode: "private" },
      owner: admin
    )
    member_copy = @family.categories.private_for(member).find_by!(name: category.name)

    assert_equal admin_copy, admin_transaction.reload.category
    assert_equal member_copy, member_transaction.reload.category
    assert Category.unscoped.find(category.id).archived_at
    assert_equal 30_000, BudgetCategory.find(household_limit.id).budgeted_spending
    assert BudgetCategory.find(household_limit.id).archived_at
  end

  test "aligned personal limits follow private category copies" do
    admin = users(:family_admin)
    member = users(:family_member)
    category = @family.categories.create!(
      name: "Aligned category to privatize",
      color: "#654321",
      lucide_icon: "car",
      sharing_mode: "aligned"
    )
    accounts(:depository).entries.create!(
      name: "Admin aligned purchase",
      date: Date.current,
      amount: 100,
      currency: @family.currency,
      entryable: Transaction.new(category: category)
    )
    member_account = @family.accounts.create!(
      owner: member,
      name: "Member private account for aligned transition",
      balance: 0,
      currency: @family.currency,
      accountable: Depository.new
    )
    member_account.entries.create!(
      name: "Member aligned purchase",
      date: Date.current,
      amount: 200,
      currency: @family.currency,
      entryable: Transaction.new(category: category)
    )
    admin_budget = Budget.find_or_bootstrap(@family, start_date: Date.current, user: admin)
    member_budget = Budget.find_or_bootstrap(@family, start_date: Date.current, user: member)
    admin_budget.budget_categories.find_by!(category: category).update!(budgeted_spending: 12_000)
    member_budget.budget_categories.find_by!(category: category).update!(budgeted_spending: 18_000)

    admin_copy = Category::ChangeSharingMode.call!(
      category: category,
      attributes: { sharing_mode: "private" },
      owner: admin
    )
    member_copy = @family.categories.private_for(member).find_by!(name: category.name)

    assert_equal 12_000, admin_budget.budget_categories.find_by!(category: admin_copy).budgeted_spending
    assert_equal 18_000, member_budget.budget_categories.find_by!(category: member_copy).budgeted_spending
  end
end
