package FS::cust_pkg;

use strict;
use vars qw(@ISA);
use FS::UID qw( getotaker );
use FS::Record qw( qsearch qsearchs );
use FS::cust_svc;
use FS::part_pkg;
use FS::cust_main;

# need to 'use' these instead of 'require' in sub { cancel, suspend, unsuspend,
# setup }
# because they load configuraion by setting FS::UID::callback (see TODO)
use FS::svc_acct;
use FS::svc_acct_sm;
use FS::svc_domain;

@ISA = qw( FS::Record );

=head1 NAME

FS::cust_pkg - Object methods for cust_pkg objects

=head1 SYNOPSIS

  use FS::cust_pkg;

  $record = new FS::cust_pkg \%hash;
  $record = new FS::cust_pkg { 'column' => 'value' };

  $error = $record->insert;

  $error = $new_record->replace($old_record);

  $error = $record->delete;

  $error = $record->check;

  $error = $record->cancel;

  $error = $record->suspend;

  $error = $record->unsuspend;

  $part_pkg = $record->part_pkg;

  $error = FS::cust_pkg::order( $custnum, \@pkgparts );
  $error = FS::cust_pkg::order( $custnum, \@pkgparts, \@remove_pkgnums ] );

=head1 DESCRIPTION

An FS::cust_pkg object represents a customer billing item.  FS::cust_pkg
inherits from FS::Record.  The following fields are currently supported:

=over 4

=item pkgnum - primary key (assigned automatically for new billing items)

=item custnum - Customer (see L<FS::cust_main>)

=item pkgpart - Billing item definition (see L<FS::part_pkg>)

=item setup - date

=item bill - date

=item susp - date

=item expire - date

=item cancel - date

=item otaker - order taker (assigned automatically if null, see L<FS::UID>)

=back

Note: setup, bill, susp, expire and cancel are specified as UNIX timestamps;
see L<perlfunc/"time">.  Also see L<Time::Local> and L<Date::Parse> for
conversion functions.

=head1 METHODS

=over 4

=item new HASHREF

Create a new billing item.  To add the item to the database, see L<"insert">.

=cut

sub table { 'cust_pkg'; }

=item insert

Adds this billing item to the database ("Orders" the item).  If there is an
error, returns the error, otherwise returns false.

=item delete

Currently unimplemented.  You don't want to delete billing items, because there
would then be no record the customer ever purchased the item.  Instead, see
the cancel method.

=cut

sub delete {
  return "Can't delete cust_pkg records!";
}

=item replace OLD_RECORD

Replaces the OLD_RECORD with this one in the database.  If there is an error,
returns the error, otherwise returns false.

Currently, custnum, setup, bill, susp, expire, and cancel may be changed.

Changing pkgpart may have disasterous effects.  See the order subroutine.

setup and bill are normally updated by calling the bill method of a customer
object (see L<FS::cust_main>).

suspend is normally updated by the suspend and unsuspend methods.

cancel is normally updated by the cancel method (and also the order subroutine
in some cases).

=cut

sub replace {
  my( $new, $old ) = ( shift, shift );

  #return "Can't (yet?) change pkgpart!" if $old->pkgpart ne $new->pkgpart;
  return "Can't change otaker!" if $old->otaker ne $new->otaker;
  return "Can't change setup once it exists!"
    if $old->getfield('setup') &&
       $old->getfield('setup') != $new->getfield('setup');
  #some logic for bill, susp, cancel?

  $new->SUPER::replace($old);
}

=item check

Checks all fields to make sure this is a valid billing item.  If there is an
error, returns the error, otherwise returns false.  Called by the insert and
replace methods.

=cut

sub check {
  my $self = shift;

  my $error = 
    $self->ut_numbern('pkgnum')
    || $self->ut_number('custnum')
    || $self->ut_number('pkgpart')
    || $self->ut_numbern('setup')
    || $self->ut_numbern('bill')
    || $self->ut_numbern('susp')
    || $self->ut_numbern('cancel')
  ;
  return $error if $error;

  return "Unknown customer"
    unless qsearchs( 'cust_main', { 'custnum' => $self->custnum } );

  return "Unknown pkgpart"
    unless qsearchs( 'part_pkg', { 'pkgpart' => $self->pkgpart } );

  $self->otaker(getotaker) unless $self->otaker;
  $self->otaker =~ /^(\w{0,16})$/ or return "Illegal otaker";
  $self->otaker($1);

  ''; #no error
}

=item cancel

Cancels and removes all services (see L<FS::cust_svc> and L<FS::part_svc>)
in this package, then cancels the package itself (sets the cancel field to
now).

If there is an error, returns the error, otherwise returns false.

=cut

sub cancel {
  my $self = shift;
  my $error;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE'; 
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  foreach my $cust_svc (
    qsearch( 'cust_svc', { 'pkgnum' => $self->pkgnum } )
  ) {
    my $part_svc = qsearchs( 'part_svc', { 'svcpart' => $cust_svc->svcpart } );

    $part_svc->svcdb =~ /^([\w\-]+)$/
      or return "Illegal svcdb value in part_svc!";
    my $svcdb = $1;
    require "FS/$svcdb.pm";

    my $svc = qsearchs( $svcdb, { 'svcnum' => $cust_svc->svcnum } );
    if ($svc) {
      $error = $svc->cancel;
      return "Error cancelling service: $error" if $error;
      $error = $svc->delete;
      return "Error deleting service: $error" if $error;
    }

    $error = $cust_svc->delete;
    return "Error deleting cust_svc: $error" if $error;

  }

  unless ( $self->getfield('cancel') ) {
    my %hash = $self->hash;
    $hash{'cancel'} = $^T;
    my $new = new FS::cust_pkg ( \%hash );
    $error = $new->replace($self);
    return $error if $error;
  }

  ''; #no errors
}

=item suspend

Suspends all services (see L<FS::cust_svc> and L<FS::part_svc>) in this
package, then suspends the package itself (sets the susp field to now).

If there is an error, returns the error, otherwise returns false.

=cut

sub suspend {
  my $self = shift;
  my $error ;

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE'; 
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  foreach my $cust_svc (
    qsearch( 'cust_svc', { 'pkgnum' => $self->pkgnum } )
  ) {
    my $part_svc = qsearchs( 'part_svc', { 'svcpart' => $cust_svc->svcpart } );

    $part_svc->svcdb =~ /^([\w\-]+)$/
      or return "Illegal svcdb value in part_svc!";
    my $svcdb = $1;
    require "FS/$svcdb.pm";

    my $svc = qsearchs( $svcdb, { 'svcnum' => $cust_svc->svcnum } );
    if ($svc) {
      $error = $svc->suspend;
      return $error if $error;
    }

  }

  unless ( $self->getfield('susp') ) {
    my %hash = $self->hash;
    $hash{'susp'} = $^T;
    my $new = new FS::cust_pkg ( \%hash );
    $error = $new->replace($self);
    return $error if $error;
  }

  ''; #no errors
}

=item unsuspend

Unsuspends all services (see L<FS::cust_svc> and L<FS::part_svc>) in this
package, then unsuspends the package itself (clears the susp field).

If there is an error, returns the error, otherwise returns false.

=cut

sub unsuspend {
  my $self = shift;
  my($error);

  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE';
  local $SIG{QUIT} = 'IGNORE'; 
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE';

  foreach my $cust_svc (
    qsearch('cust_svc',{'pkgnum'=> $self->pkgnum } )
  ) {
    my $part_svc = qsearchs( 'part_svc', { 'svcpart' => $cust_svc->svcpart } );

    $part_svc->svcdb =~ /^([\w\-]+)$/
      or return "Illegal svcdb value in part_svc!";
    my $svcdb = $1;
    require "FS/$svcdb.pm";

    my $svc = qsearchs( $svcdb, { 'svcnum' => $cust_svc->svcnum } );
    if ($svc) {
      $error = $svc->unsuspend;
      return $error if $error;
    }

  }

  unless ( ! $self->getfield('susp') ) {
    my %hash = $self->hash;
    $hash{'susp'} = '';
    my $new = new FS::cust_pkg ( \%hash );
    $error = $new->replace($self);
    return $error if $error;
  }

  ''; #no errors
}

=item part_pkg

Returns the definition for this billing item, as an FS::part_pkg object (see
L<FS::part_pkg).

=cut

sub part_pkg {
  my $self = shift;
  qsearchs( 'part_pkg', { 'pkgpart' => $self->pkgpart } );
}

=back

=head1 SUBROUTINES

=over 4

=item order CUSTNUM, PKGPARTS_ARYREF, [ REMOVE_PKGNUMS_ARYREF ]

CUSTNUM is a customer (see L<FS::cust_main>)

PKGPARTS is a list of pkgparts specifying the the billing item definitions (see
L<FS::part_pkg>) to order for this customer.  Duplicates are of course
permitted.

REMOVE_PKGNUMS is an optional list of pkgnums specifying the billing items to
remove for this customer.  The services (see L<FS::cust_svc>) are moved to the
new billing items.  An error is returned if this is not possible (see
L<FS::pkg_svc>).

=cut

sub order {
  my($custnum,$pkgparts,$remove_pkgnums)=@_;

  my(%part_pkg);
  # generate %part_pkg
  # $part_pkg{$pkgpart} is true iff $custnum may purchase $pkgpart
    my($cust_main)=qsearchs('cust_main',{'custnum'=>$custnum});
    my($agent)=qsearchs('agent',{'agentnum'=> $cust_main->agentnum });

    my($type_pkgs);
    foreach $type_pkgs ( qsearch('type_pkgs',{'typenum'=> $agent->typenum }) ) {
      my($pkgpart)=$type_pkgs->pkgpart;
      $part_pkg{$pkgpart}++;
    }
  #

  my(%svcnum);
  # generate %svcnum
  # for those packages being removed:
  #@{ $svcnum{$svcpart} } goes from a svcpart to a list of FS::Record
  # objects (table eq 'cust_svc')
  my($pkgnum);
  foreach $pkgnum ( @{$remove_pkgnums} ) {
    my($cust_svc);
    foreach $cust_svc (qsearch('cust_svc',{'pkgnum'=>$pkgnum})) {
      push @{ $svcnum{$cust_svc->getfield('svcpart')} }, $cust_svc;
    }
  }
  
  my(@cust_svc);
  #generate @cust_svc
  # for those packages the customer is purchasing:
  # @{$pkgparts} is a list of said packages, by pkgpart
  # @cust_svc is a corresponding list of lists of FS::Record objects
  my($pkgpart);
  foreach $pkgpart ( @{$pkgparts} ) {
    return "Customer not permitted to purchase pkgpart $pkgpart!"
      unless $part_pkg{$pkgpart};
    push @cust_svc, [
      map {
        ( $svcnum{$_} && @{ $svcnum{$_} } ) ? shift @{ $svcnum{$_} } : ();
      } (split(/,/,
       qsearchs('part_pkg',{'pkgpart'=>$pkgpart})->getfield('services')
      ))
    ];
  }

  #check for leftover services
  foreach (keys %svcnum) {
    next unless @{ $svcnum{$_} };
    return "Leftover services!";
  }

  #no leftover services, let's make changes.
 
  local $SIG{HUP} = 'IGNORE';
  local $SIG{INT} = 'IGNORE'; 
  local $SIG{QUIT} = 'IGNORE';
  local $SIG{TERM} = 'IGNORE';
  local $SIG{TSTP} = 'IGNORE'; 

  #first cancel old packages
#  my($pkgnum);
  foreach $pkgnum ( @{$remove_pkgnums} ) {
    my($old) = qsearchs('cust_pkg',{'pkgnum'=>$pkgnum});
    return "Package $pkgnum not found to remove!" unless $old;
    my(%hash) = $old->hash;
    $hash{'cancel'}=$^T;   
    my($new) = create FS::cust_pkg ( \%hash );
    my($error)=$new->replace($old);
    return $error if $error;
  }

  #now add new packages, changing cust_svc records if necessary
#  my($pkgpart);
  while ($pkgpart=shift @{$pkgparts} ) {
 
    my($new) = create FS::cust_pkg ( {
                                       'custnum' => $custnum,
                                       'pkgpart' => $pkgpart,
                                    } );
    my($error) = $new->insert;
    return $error if $error; 
    my($pkgnum)=$new->getfield('pkgnum');
 
    my($cust_svc);
    foreach $cust_svc ( @{ shift @cust_svc } ) {
      my(%hash) = $cust_svc->hash;
      $hash{'pkgnum'}=$pkgnum;
      my($new) = create FS::cust_svc ( \%hash );
      my($error)=$new->replace($cust_svc);
      return $error if $error;
    }
  }  

  ''; #no errors
}

=back

=head1 VERSION

$Id: cust_pkg.pm,v 1.4 1998-12-29 11:59:45 ivan Exp $

=head1 BUGS

sub order is not OO.  Perhaps it should be moved to FS::cust_main and made so?

In sub order, the @pkgparts array (passed by reference) is clobbered.

Also in sub order, no money is adjusted.  Once FS::part_pkg defines a standard
method to pass dates to the recur_prog expression, it should do so.

FS::svc_acct, FS::svc_acct_sm, and FS::svc_domain are loaded via 'use' at 
compile time, rather than via 'require' in sub { setup, suspend, unsuspend,
cancel } because they use %FS::UID::callback to load configuration values.
Probably need a subroutine which decides what to do based on whether or not
we've fetched the user yet, rather than a hash.  See FS::UID and the TODO.

=head1 SEE ALSO

L<FS::Record>, L<FS::cust_main>, L<FS::part_pkg>, L<FS::cust_svc>
, L<FS::pkg_svc>, schema.html from the base documentation

=head1 HISTORY

ivan@voicenet.com 97-jul-1 - 21

fixed for new agent->agent_type->type_pkgs in &order ivan@sisd.com 98-mar-7

pod ivan@sisd.com 98-sep-21

$Log: cust_pkg.pm,v $
Revision 1.4  1998-12-29 11:59:45  ivan
mostly properly OO, some work still to be done with svc_ stuff

Revision 1.3  1998/11/15 13:01:35  ivan
allow pkgpart changing (for per-customer custom pricing).  warn about it in doc

Revision 1.2  1998/11/12 03:42:45  ivan
added label method


=cut

1;

