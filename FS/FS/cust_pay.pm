package FS::cust_pay;

use strict;
use vars qw( @ISA $conf $unsuspendauto );
use Business::CreditCard;
use FS::UID qw( dbh );
use FS::Record qw( dbh qsearch qsearchs dbh );
use FS::cust_bill;
use FS::cust_bill_pay;
use FS::cust_main;

@ISA = qw( FS::Record );

#ask FS::UID to run this stuff for us later
$FS::UID::callback{'FS::cust_pay'} = sub { 

  $conf = new FS::Conf;
  $unsuspendauto = $conf->exists('unsuspendauto');

};

=head1 NAME

FS::cust_pay - Object methods for cust_pay objects

=head1 SYNOPSIS

  use FS::cust_pay;

  $record = new FS::cust_pay \%hash;
  $record = new FS::cust_pay { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

=head1 DESCRIPTION

An FS::cust_pay object represents a payment; the transfer of money from a
customer.  FS::cust_pay inherits from FS::Record.  The following fields are
currently supported:

=over 4

=item paynum - primary key (assigned automatically for new payments)

=item custnum - customer (see L<FS::cust_main>)

=item paid - Amount of this payment

=item _date - specified as a UNIX timestamp; see L<perlfunc/"time">.  Also see
L<Time::Local> and L<Date::Parse> for conversion functions.

=item payby - `CARD' (credit cards), `BILL' (billing), or `COMP' (free)

=item payinfo - card number, check #, or comp issuer (4-8 lowercase alphanumerics; think username), respectively

=item paybatch - text field for tracking card processing

=back

=head1 METHODS

=over 4 

=item new HASHREF

Creates a new payment.  To add the payment to the databse, see L<"insert">.

=cut

sub table { 'cust_pay'; }

=item insert

Adds this payment to the database.

For backwards-compatibility and convenience, if the additional field invnum
is defined, an FS::cust_bill_pay record for the full amount of the payment
will be created.  In this case, custnum is optional.

=cut

sub insert {
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  if ( $self->invnum ) {
    my $cust_bill = qsearchs('cust_bill', { 'invnum' => $self->invnum } )
      or do {
        $dbh->rollback if $oldAutoCommit;
        return "Unknown cust_bill.invnum: ". $self->invnum;
      };
    $self->custnum($cust_bill->custnum );
  }

  my $cust_main = qsearchs( 'cust_main', { 'custnum' => $self->custnum } );
  my $old_balance = $cust_main->balance;

  my $error = $self->check;
  return $error if $error;

  $error = $self->SUPER::insert;
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return "error inserting $self: $error";
  }

  if ( $self->invnum ) {
    my $cust_bill_pay = new FS::cust_bill_pay {
      'invnum' => $self->invnum,
      'paynum' => $self->paynum,
      'amount' => $self->paid,
      '_date'  => $self->_date,
    };
    $error = $cust_bill_pay->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return "error inserting $cust_bill_pay: $error";
    }
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  #false laziness w/ cust_credit::insert
  if ( $unsuspendauto && $old_balance && $cust_main->balance <= 0 ) {
    my @errors = $cust_main->unsuspend;
    #return 
    # side-fx with nested transactions?  upstack rolls back?
    warn "WARNING:Errors unsuspending customer ". $cust_main->custnum. ": ".
         join(' / ', @errors)
      if @errors;
  }
  #eslaf

  '';

}

sub upgrade_replace { #1.3.x->1.4.x
  my $self = shift;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';
  local $SIG{PIPE} = 'IGNORE';

  my $oldAutoCommit = $FS::UID::AutoCommit;
  local $FS::UID::AutoCommit = 0;
  my $dbh = dbh;

  my $error = $self->check;
  return $error if $error;

  my %new = $self->hash;
  my $new = FS::cust_pay->new(\%new);

  if ( $self->invnum ) {
    my $cust_bill_pay = new FS::cust_bill_pay {
      'invnum' => $self->invnum,
      'paynum' => $self->paynum,
      'amount' => $self->paid,
      '_date'  => $self->_date,
    };
    $error = $cust_bill_pay->insert;
    if ( $error ) {
      $dbh->rollback if $oldAutoCommit;
      return $error;
    }
    $new->custnum($cust_bill_pay->cust_bill->custnum);
  } else {
    die;
  }

  $error = $new->SUPER::replace($self);
  if ( $error ) {
    $dbh->rollback if $oldAutoCommit;
    return $error;
  }

  $dbh->commit or die $dbh->errstr if $oldAutoCommit;

  '';


}

=item delete

Currently unimplemented (accounting reasons).

=cut

sub delete {
  return "Can't (yet?) delete cust_pay records!";
}

=item replace OLD_RECORD

Currently unimplemented (accounting reasons).

=cut

sub replace {
   return "Can't (yet?) modify cust_pay records!";
}

=item check

Checks all fields to make sure this is a valid payment.  If there is an error,
returns the error, otherwise returns false.  Called by the insert method.

=cut

sub check {
  my $self = shift;

  my $error =
    $self->ut_numbern('paynum')
    || $self->ut_numbern('custnum')
    || $self->ut_money('paid')
    || $self->ut_numbern('_date')
    || $self->ut_textn('paybatch')
  ;
  return $error if $error;

  return "paid must be > 0 " if $self->paid == 0;

  return "unknown cust_main.custnum: ". $self->custnum
    unless $self->invnum
           || qsearchs( 'cust_main', { 'custnum' => $self->custnum } );

  $self->_date(time) unless $self->_date;

  $self->payby =~ /^(CARD|BILL|COMP)$/ or return "Illegal payby";
  $self->payby($1);

  #false laziness with cust_refund::check
  if ( $self->payby eq 'CARD' ) {
    my $payinfo = $self->payinfo;
    $payinfo =~ s/\D//g;
    $self->payinfo($payinfo);
    if ( $self->payinfo ) {
      $self->payinfo =~ /^(\d{13,16})$/
        or return "Illegal (mistyped?) credit card number (payinfo)";
      $self->payinfo($1);
      validate($self->payinfo) or return "Illegal credit card number";
      return "Unknown card type" if cardtype($self->payinfo) eq "Unknown";
    } else {
      $self->payinfo('N/A');
    }

  } else {
    $error = $self->ut_textn('payinfo');
    return $error if $error;
  }

  ''; #no error

}

=item cust_bill_pay

Returns all applications to invoices (see L<FS::cust_bill_pay>) for this
payment.

=cut

sub cust_bill_pay {
  my $self = shift;
  sort { $a->_date <=> $b->_date }
    qsearch( 'cust_bill_pay', { 'paynum' => $self->paynum } )
  ;
}

=item unapplied

Returns the amount of this payment that is still unapplied; which is
paid minus all payment applications (see L<FS::cust_bill_pay>).

=cut

sub unapplied {
  my $self = shift;
  my $amount = $self->paid;
  $amount -= $_->amount foreach ( $self->cust_bill_pay );
  sprintf("%.2f", $amount );
}

=back

=head1 VERSION

$Id: cust_pay.pm,v 1.12 2002-01-24 11:52:02 ivan Exp $

=head1 BUGS

Delete and replace methods.

=head1 SEE ALSO

L<FS::cust_bill_pay>, L<FS::cust_bill>, L<FS::Record>, schema.html from the
base documentation.

=cut

1;

