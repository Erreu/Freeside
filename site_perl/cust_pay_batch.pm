package FS::cust_pay_batch;

use strict;
use vars qw( @ISA );
use FS::Record;
use Business::CreditCard;

@ISA = qw( FS::Record );

=head1 NAME

FS::cust_pay_batch - Object methods for batch cards

=head1 SYNOPSIS

  use FS::cust_pay_batch;

  $record = new FS::cust_pay_batch \%hash;
  $record = new FS::cust_pay_batch { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pay_batch object represents a credit card transaction ready to be
batched (sent to a processor).  FS::cust_pay_batch inherits from FS::Record.  
Typically called by the collect method of an FS::cust_main object.  The
following fields are currently supported:

=over 4

=item trancode - 77 for charges

=item cardnum

=item exp - card expiration 

=item amount 

=item invnum - invoice

=item custnum - customer 

=item payname - name on card 

=item first - name 

=item last - name 

=item address1 

=item address2 

=item city 

=item state 

=item zip 

=item country 

=back

=head1 METHODS

=over 4

=item new HASHREF

Creates a new record.  To add the record to the database, see L<"insert">.

Note that this stores the hash reference, not a distinct copy of the hash it
points to.  You can ask the object for a copy with the I<hash> method.

=cut

sub table { 'cust_pay_batch'; }

=item insert

Adds this record to the database.  If there is an error, returns the error,
otherwise returns false.

=item delete

Delete this record from the database.  If there is an error, returns the error,
otherwise returns false.

=item replace OLD_RECORD

#inactive
#
#Replaces the OLD_RECORD with this one in the database.  If there is an error,
#returns the error, otherwise returns false.

=cut

sub replace {
  return "Can't (yet?) replace batched transactions!";
}

=item check

Checks all fields to make sure this is a valid transaction.  If there is
an error, returns the error, otherwise returns false.  Called by the insert
and repalce methods.

=cut

sub check {
  my $self = shift;

  my $error = 
      $self->ut_numbern('trancode')
    || $self->ut_number('cardnum') 
    || $self->ut_money('amount')
    || $self->ut_number('invnum')
    || $self->ut_number('custnum')
    || $self->ut_text('address1')
    || $self->ut_textn('address2')
    || $self->ut_text('city')
    || $self->ut_text('state')
  ;

  return $error if $error;

  $self->getfield('last') =~ /^([\w \,\.\-\']+)$/ or return "Illegal last name";
  $self->setfield('last',$1);

  $self->first =~ /^([\w \,\.\-\']+)$/ or return "Illegal first name";
  $self->first($1);

  my $cardnum = $self->cardnum;
  $cardnum =~ s/\D//g;
  $cardnum =~ /^(\d{13,16})$/
    or return "Illegal credit card number";
  $cardnum = $1;
  $self->cardnum($cardnum);
  validate($cardnum) or return "Illegal credit card number";
  return "Unknown card type" if cardtype($self->payinfo) eq "Unknown";

  if ( $self->exp eq '' ) {
    return "Expriation date required";
    $self->exp('');
  } else {
    $self->exp =~ /^(\d{1,2})[\/\-](\d{2}(\d{2})?)$/
      or return "Illegal expiration date";
    if ( length($2) == 4 ) {
      $self->exp("$2-$1-01");
    } elsif ( $2 > 98 ) { #should pry change to check for "this year"
      $self->exp("19$2-$1-01");
    } else {
      $self->exp("20$2-$1-01");
    }
  }

  if ( $self->payname eq '' ) {
    $self->payname( $self->first. " ". $self->getfield('last') );
  } else {
    $self->payname =~ /^([\w \,\.\-\']+)$/
      or return "Illegal billing name";
    $self->payname($1);
  }

  $self->zip =~ /^([\w\-]{10})$/ or return "Illegal zip";
  $self->zip($1);

  $self->country =~ /^(\w\w)$/ or return "Illegal \w\wy";
  $self->country($1);

  #check invnum, custnum, ?

  ''; #no error
}

=back

=head1 VERSION

$Id: cust_pay_batch.pm,v 1.3 1998-12-29 11:59:44 ivan Exp $

=head1 BUGS

There should probably be a configuration file with a list of allowed credit
card types.

=head1 SEE ALSO

L<FS::cust_main>, L<FS::Record>

=head1 HISTORY

ivan@voicenet.com 97-jul-1

added hfields
ivan@sisd.com 97-nov-13

$Log: cust_pay_batch.pm,v $
Revision 1.3  1998-12-29 11:59:44  ivan
mostly properly OO, some work still to be done with svc_ stuff

Revision 1.2  1998/11/18 09:01:44  ivan
i18n! i18n!

Revision 1.1  1998/11/15 05:19:58  ivan
long overdue

Revision 1.3  1998/11/15 04:33:00  ivan
updates for newest versoin

Revision 1.2  1998/11/15 03:48:49  ivan
update for current version


=cut

1;

