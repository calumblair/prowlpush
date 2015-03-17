%prowlpush: send a notification to an iOS device via the Prowl API
%syntax: prowlpush( eventname, varargin)
%example: prowlpush('long computation finished');
%on first run you will be prompted via the Prowl website to allow this tool to send you
%notifications. This only needs to be done once.
% required inputs:
%	none
% optional inputs:
%	eventname: a string describing the event you want notified about
% optional name-value parameter inputs:
%  'description',__description__ : a longer string describing the event
%  'application',__application__ : string, details of the MATLAB application the
%								   notification was sent from
%	'url', __url__				 : a URL to open on the device
%	'APIFile', filename			 : alternative filename to hold your API key (Normally
%								   stored in MATLAB's prefdir)
%
% outputs:
%	success: 1 if notification succeeded, 0 if not.
%requires a (free) prowl account ( http://www.prowlapp.com )and a Prowl app on the device
%also requires xml2struct.m from the file exchange

%calum blair
%16/03/2015


function success = prowlpush(varargin)
success = 0;
%%%%%%%%%%%% set up application defaults
baseurl= 'https://api.prowlapp.com/publicapi/';
%key for 'MATLAB Notification Tool':
providerkey = '9b5c63bf4fc892e6cee3ab1624e08b82f160ddd8';

%%%%%%%%%%%%%%%%%%%%%%%%%%% set up input defaults
%form application details
vernum = version('-release');
pid = feature('getpid');
if ispc, hostname = getenv('COMPUTERNAME'); else hostname = getenv('HOSTNAME'); end
application_string = ['MATLAB ' vernum ' on ' hostname ', PID ' num2str(pid)];

verify_priority=@(x)(isnumeric(x) && x<=2  && x>= -2 && round(x) == x);
default_apifile_loc =  [prefdir '/prowlapifile.xml'];
%%%%%%%%%%%%parse inputs
p=inputParser;
p.addOptional('event','Computation finished',@(x)(isstr(x)));
p.addParamValue('priority',0,verify_priority);
p.addParamValue('application',application_string);
%other parameters are 'url [512]', 'event [1024]' and 'description [10000]'
p.addParamValue('url','');
%p.addParamValue('event','');
p.addParamValue('description','');
p.addParamValue('APIFile', default_apifile_loc);
p.parse(varargin{:}); %guess what happens if you don't include the {:} ?
%fix the holes in inputParser. an optional first argument isn't actually
%optional.
eventname = p.Results.event;
if isempty(eventname)
	eventname = 'Computation finished';
end

%api file should be stored in pref dir; try that first
try
	keyfile = xml2struct(p.Results.APIFile);
	apikey = keyfile.prowl.retrieve.Attributes.apikey;
catch err1
	%api file not present.
	try
		[token, tokenurl] = prowlgettokenforuserreg(baseurl, providerkey);
		[apikey, success] = prowlgetapikey(baseurl, providerkey,token, tokenurl,0, p.Results.APIFile);
		assert(success>0);
	catch err2
		error('failed to get user token from server; do you have a Prowl account and does it allow MATLAB?');
		err1.msg
		err2.msg
	end
end

% try a push
fprintf('Sending message: %s\n',eventname);
success = prowlpushnotification(apikey,baseurl,p.Results.priority,p.Results.url,...
	p.Results.application,...
	eventname, p.Results.description);
end


%push a prowl notification
function success = prowlpushnotification(apikey,baseurl,priority,url,application,event, description)
%assume the Prowl API will re-check all our inputs for us.
tempfile = [prefdir '/prowltemppushfile.xml'];
ps = num2str(priority);

[fileout, success]= urlwrite([baseurl 'add'],tempfile,'post',...
	{'apikey', apikey, 'priority', ps, 'url', url, 'application',application,...
	'event', event, 'description', description});
if success
	prowlstruct= xml2struct(fileout);
	code = str2double(prowlstruct.prowl.success.Attributes.code);
	if code == 200 %SUCCESS
		fprintf('Notification sent successfully.\n');
	else
			error('failed to send notification; is API key present?');	
	end
	delete( fileout);
else
	error('failed to send notification; is API key present?');	
end
end


%return a uew user token based on our API key
function [token, nexturl]= prowlgettokenforuserreg(baseurl, providerkey)
nexturl='';
tokenfile = [prefdir '/prowltokenfile.xml'];
[fileout, success] = urlwrite([baseurl 'retrieve/token'],tokenfile,...
	'Get',{'providerkey',providerkey});
if success
	%run xml2struct; dont do this ourselves as matlab xml parsing is
	%horrible
	prowlstruct= xml2struct(fileout);
	code = str2double(prowlstruct.prowl.success.Attributes.code);
	if code == 200 %SUCCESS
		token = prowlstruct.prowl.retrieve.Attributes.token;
		nexturl= prowlstruct.prowl.retrieve.Attributes.url;
		delete(fileout);
	else
		error('api call to obtain a token failed. Code %d.  stopping',code);
	end
end
end

%return an user-specific api key. This gets saved in the prefdir so we can
%recall it on future runs.
function [apikey, success]= prowlgetapikey(baseurl, providerkey, token, tokenurl,...
	already_prompted,	api_file_location)

%first assume the user has authed us already
[fileout, success]= urlwrite([baseurl 'retrieve/apikey'],api_file_location,'Get',...
	{'providerkey',providerkey,'token',token});

if success
	%run xml2struct; dont do this ourselves as matlab xml parsing is
	%horrible
	
	prowlstruct= xml2struct(fileout);
	code = str2double(prowlstruct.prowl.success.Attributes.code);
	if code == 200 %SUCCESS
		apikey= prowlstruct.prowl.retrieve.Attributes.apikey;
	else
		error('api call to obtain an api key failed. Code %d.  stopping',code);
	end
else
	if ~already_prompted
		%user has not yet authed us so get them to do that
		web(tokenurl,'-browser');
		input('\nHave you:\n(1) Registered for a Prowl account?\n(2) Granted the MATLAB Notification Tool authorisation to your prowl account? \nComplete authorisation form in browser and press Enter when done:');
		[apikey, success] = prowlgetapikey(baseurl, providerkey,token, tokenurl,1, api_file_location);
		fprintf('Remember to associate a Prowl key with your iOS device.\n');
	else
		error('failed; should already have authorised key');
	end
end
end


