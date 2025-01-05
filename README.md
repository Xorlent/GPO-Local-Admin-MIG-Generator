# Local Admin Janitor
This tool will scan hosts in a specified Active Directory OU, retrieve all local administrator memberships, then create the GPO migration files necessary to apply and enforce local admin memberships to all of the specified hosts.
## Background
In many organizations local administrator rights are not enforced via GPO but rather the GPO-specified local administrative users are additive, so naturally we end up with rights creep that we need to regain control of.  This tool collects the local admininstrative users for all online computers within a specified Active Directory OU/CN.  This information is then processed to create hosts groups with common assigned local administrator rights, and finally outputting [GPO Migration table](https://learn.microsoft.com/en-us/previous-versions/windows/desktop/gpmc/using-migration-tables) files that can be used to apply and enforce these rights on specified hosts.
## To-Do
1. Add code to create the needed placeholder domain users and groups
2. Add code to New-MigTable to check for the placeholder objects, verify disabled state, count and use this count as the max value for MIGs
3. Add code to install GPOs using the generated MIG files
4. Add code to apply the GPOs to the requisite computer objects to enforce local admin rights
