package FS::table_name;

use strict;
use vars qw( @ISA );
use FS::Record qw( qsearch qsearchs );

@ISA = qw(FS::Record);

=head1 NAME

FS::table_name - Object methods for table_name records

=head1 SYNOPSIS

  use FS::table_name;

  $record = new FS::table_name \%hash;
  $record = new FS::table_name { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::table_name object represents an example.  FS::table_name inherits from
FS::Record.  The following fields are currently supported:

=over 4

=item field - description

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new example.  To add the example to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

# the new method can be inherited from FS::Record, if a table method is defined

sub table { 'table_name'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=cut

# the insert method can be inherited from FS::Record

=item delete

Delete this record from the database.

=cut

# the delete method can be inherited from FS::Record

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

=cut

# the replace method can be inherited from FS::Record

=item check

Checks all fields to make sure this is a valid example.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and replace methods.

=cut

# the check method should currently be supplied - FS::Record contains some
# data checking routines

sub check {
  my $self = shift;

  ''; #no error
}

=back

=head1 VERSION

$Id: table_template.pm,v 1.4 1998-12-29 11:59:57 ivan Exp $

=head1 BUGS

The author forgot to customize this manpage.

=head1 SEE ALSO

L<FS::Record>, schema.html from the base documentation.

=head1 HISTORY

ivan@voicenet.com 97-jul-1

added hfields
ivan@sisd.com 97-nov-13

$Log: table_template.pm,v $
Revision 1.4  1998-12-29 11:59:57  ivan
mostly properly OO, some work still to be done with svc_ stuff

Revision 1.3  1998/11/15 04:33:00  ivan
updates for newest versoin

Revision 1.2  1998/11/15 03:48:49  ivan
update for current version


=cut

1;

