Feature: Various things on the homepage
 
  Before do
  end

  @browserstack
#  @javascript
  Scenario: Logged out

  Given I have the site skins
    And I am on the homepage
#    And I take a screenshot
  Then I should see "The Archive of Our Own is a project of the Organization for Transformative Works."
  When I follow "Diversity Statement"
  Then I should see "You are welcome at the Archive of Our Own."
  When I follow "DMCA Policy"
  Then I should see "safe harbor"
  When I follow "Site Map"
    And I follow "Donations"
  Then I should see "There are two main ways to support the AO3 - donating your time or money"
