<%

#untaint invnum
my($query) = $cgi->keywords;
$query =~ /^((.+)-)?(\d+)$/;
my $templatename = $2;
my $invnum = $3;

my $conf = new FS::Conf;

my $cust_bill = qsearchs('cust_bill',{'invnum'=>$invnum});
die "Invoice #$invnum not found!" unless $cust_bill;
my $custnum = $cust_bill->getfield('custnum');

#my $printed = $cust_bill->printed;

my $link = $templatename ? "$templatename-$invnum" : $invnum;

%>
<%= header('Invoice View', menubar(
  "Main Menu" => $p,
  "View this customer (#$custnum)" => "${p}view/cust_main.cgi?$custnum",
)) %>

<% if ( $cust_bill->owed > 0 ) { %>
  <A HREF="<%= $p %>edit/cust_pay.cgi?<%= $invnum %>">Enter payments (check/cash) against this invoice</A> |
<% } %>

<A HREF="<%= $p %>misc/print-invoice.cgi?<%= $link %>">Re-print this invoice</A>

<% if ( grep { $_ ne 'POST' } $cust_bill->cust_main->invoicing_list ) { %>
  | <A HREF="<%= $p %>misc/email-invoice.cgi?<%= $link %>">Re-email
      this invoice</A>
<% } %>

<% if ( $conf->exists('hylafax') && length($cust_bill->cust_main->fax) ) { %>
  | <A HREF="<%= $p %>misc/fax-invoice.cgi?<%= $link %>">Re-fax
      this invoice</A>
<% } %>

<BR><BR>

<% if ( $conf->exists('invoice_latex') ) { %>
  <A HREF="<%= $p %>view/cust_bill-pdf.cgi?<%= $link %>.pdf">View typeset invoice</A>
  <BR><BR>
<% } %>

<% #false laziness with search/cust_bill_event.cgi
   unless ( $templatename ) { %>

  <%= table() %>
  <TR>
    <TH>Event</TH>
    <TH>Date</TH>
    <TH>Status</TH>
  </TR>

  <% foreach my $cust_bill_event (
       sort { $a->_date <=> $b->_date } $cust_bill->cust_bill_event
     ) {

    my $status = $cust_bill_event->status;
    $status .= ': '. encode_entities($cust_bill_event->statustext)
      if $cust_bill_event->statustext;
    my $part_bill_event = $cust_bill_event->part_bill_event;
  %>
    <TR>
      <TD><%= $part_bill_event->event %>
  
        <% if (
          $part_bill_event->plan eq 'send_alternate'
          && $part_bill_event->plandata =~ /^(agent_)?templatename (.*)$/m
        ) {
          my $alt_templatename = $2;
          my $alt_link = "$alt_templatename-$invnum";
        %>
          ( <A HREF="<%= $p %>view/cust_bill.cgi?<%= $alt_link %>">view</A>
          | <A HREF="<%= $p %>view/cust_bill-pdf.cgi?<%= $alt_link %>.pdf">view
              typeset</A>
          | <A HREF="<%= $p %>misc/print-invoice.cgi?<%= $alt_link %>">re-print</A>
          <% if ( grep { $_ ne 'POST' }
                       $cust_bill->cust_main->invoicing_list ) { %>
            | <A HREF="<%= $p %>misc/email-invoice.cgi?<%= $alt_link %>">re-email</A>
          <% } %>
                       
          <% if ( $conf->exists('hylafax')
                  && length($cust_bill->cust_main->fax) ) { %>
            | <A HREF="<%= $p %>misc/fax-invoice.cgi?<%= $alt_link %>">re-fax</A>
          <% } %>

          )
        <% } %>
  
      </TD>
      <TD><%= time2str("%a %b %e %T %Y", $cust_bill_event->_date) %></TD>
      <TD><%= $status %></TD>
    </TR>
  <% } %>

  </TABLE>
  <BR>

<% } %>

<% if ( $conf->exists('invoice_html') ) { %>
  <%= join('', $cust_bill->print_html('', $templatename) ) %>
<% } else { %>
  <PRE><%= join('', $cust_bill->print_text('', $templatename) ) %></PRE>
<% } %>

</BODY></HTML>
