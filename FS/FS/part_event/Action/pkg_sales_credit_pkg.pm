package FS::part_event::Action::pkg_sales_credit_pkg;
use base qw( FS::part_event::Action::Mixin::pkg_sales_credit
             FS::part_event::Action::Mixin::credit_pkg
             FS::part_event::Action::pkg_sales_credit );

sub description { 'Credit the package sales person an amount based on the referred package'; }

1;
