package FS::part_event::Condition::has_pkgpart;
use base qw( FS::part_event::Condition );

use strict;

sub description { 'Customer has uncancelled specific package(s)'; }

sub eventtable_hashref {
    { 'cust_main' => 1,
      'cust_bill' => 1,
      'cust_pkg'  => 1,
    };
}

sub option_fields {
  ( 
    'if_pkgpart' => { 'label'    => 'Only packages: ',
                      'type'     => 'select-part_pkg',
                      'multiple' => 1,
                    },
  );
}

sub condition {
  my( $self, $object) = @_;

  my $cust_main = $self->cust_main($object);

  my $if_pkgpart = $self->option('if_pkgpart') || {};
  grep $if_pkgpart->{ $_->pkgpart }, $cust_main->ncancelled_pkgs;

}

#XXX 
#sub condition_sql {
#
#}

1;
