# Any configuration directives you include  here will override 
# RT's default configuration file, RT_Config.pm
#
# To include a directive here, just copy the equivalent statement
# from RT_Config.pm and change the value. We've included a single
# sample value below.
#
# This file is actually a perl module, so you can include valid
# perl code, as well.
#
# The converse is also true, if this file isn't valid perl, you're
# going to run into trouble. To check your SiteConfig file, use
# this comamnd:
#
#   perl -c /path/to/your/etc/RT_SiteConfig.pm

#Set( $rtname, 'example.com');

# These settings should have been inserted by the initial Freeside install.
# Sometimes you may want to change domain, timezone, or freeside::URL later,
# everything else should probably stay untouched.

Set($rtname, '%%%RT_DOMAIN%%%');
Set($Organization, '%%%RT_DOMAIN%%%');

Set($Timezone, '%%%RT_TIMEZONE%%%');

Set($WebExternalAuth, 1);
Set($WebFallbackToInternal, 1); #no
Set($WebExternalAuto, 1);

$RT::URI::freeside::IntegrationType = 'Internal';
$RT::URI::freeside::URL = '%%%FREESIDE_URL%%%';

$RT::URI::freeside::URL =~ m(^(https?://[^/]+)(/.*)$)i;
Set($WebBaseURL, $1);
Set($WebPath, "$2/rt");

Set($DatabaseHost   , '');

# These settings are user-editable.

#old, RT 3.4 style (deprecated, useless):
#$RT::MyTicketsLength = 10;
#NEW, RT 3.6 style (uncomment to use):
#Set($DefaultSummaryRows, 10);

#does this do anything in RT 3.8??
Set($QuickCreateLong, 0); #set to true to cause quick ticket creation to
                          #redirect to the "long" ticket creation screen
                          #instead of just creating a ticket with the subject.

Set($MessageBoxWidth, 80);

#Set(@Plugins,(qw(Extension::QuickDelete RT::FM)));
1;
