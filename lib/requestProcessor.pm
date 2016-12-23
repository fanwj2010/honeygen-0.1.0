#!/usr/bin/perl -w
package requestProcessor;
use strict;
use warnings;
use common;
use XML::SAX::ParserFactory;
use XML::Validator::Schema;
use XML::LibXML;

require Exporter;
our(@EXPORT, @ISA, @EXPORT_OK);
@ISA=qw(Exporter);
@EXPORT=qw(getParas validate_schema check_content check_scenario check_template create_scenario);
@EXPORT_OK=qw();

sub getParas{
  my @paras = @_;
  #my $para = shift;
  
  if($#paras<=0){
        print "Welcome to use HoneyGen:
        -h print the help information.
        -f [filename] the file is the configuration or reconfiguration file.
        -c check the schema of the file.
        -g generate the technology independent honeynet description.
        -t deploy the honeynet by corresponding distributed deployment tool.
        \n";
        if($#paras==0&&$paras[0] eq "-f"){
            print "[Warning]: The request configuration file is required.\n\n";
                
        }
        exit 0;
   } 
   if($#paras >= 1 && $#paras < 2){
        print "type options:
        -c check the schema of the file.
        -g generate the technology independent honeynet description.
        -t deploy the honeynet by corresponding distributed deployment tool.
        \n";
         exit 0;
    }
    if($#paras >= 2){
         print "Welcome to use HoneyGen:\n";
    }
  return @paras;
}

#sub check_req{
#    my $xml_req = $_[0];
#    # create a new validator object, using TIHDL_request.xsd
#    my $xmlschema = XML::LibXML::Schema->(location => '../TIHDL_XMLSchema/TIHDL_request.xsd');
    # validate foo.xml against foo.xsd
#    eval { $xmlschema->validate($xml_req) };
#    die "File failed validation: $@" if $@;
#}

sub validate_schema{
    my $xml_req = $_[0];
    # create a new validator object, using TIHDL_core.xsd
    my $validator = XML::Validator::Schema->new(file => '../XMLSchema/HoneyGen.xsd');
    # create a SAX parser and assign the validator as a Handler
    my $parser = XML::SAX::ParserFactory->parser(Handler => $validator);
    # validate foo.xml against foo.xsd
    eval { $parser->parse_uri($xml_req) };
    die "File failed validation: $@" if $@;
    print "The validation of the request configuration file is successful.\n";
}

sub check_content{
    my $xml_req = $_[0];
    my $root_req = $xml_req->getDocumentElement;
    my $request = $root_req->getAttribute('request');
    #my $mode = $root_req->getAttribute('mode');
    my @nodes_req = $xml_req->findnodes('/honeynet/name');
    my $scenario_name = $nodes_req[$#nodes_req]->textContent;
    my $bool_s = check_scenario($scenario_name);
    if($request eq "create" || $request eq "add"){
        if($bool_s == 1){
             print "The scenario [$scenario_name] has been created.\n";
             exit 0;
        }
    }
    if($request eq "set" || $request eq "del"){
        if($bool_s == 0){
             print "The scenario [$scenario_name] does not exsit.\n";
             exit 0;
        }
    }
=pod
    if($mode eq "custom"){
       my $bool_custom = $xml_req->exists('/honeynet/template'); 
       if($bool_custom == 1){
          my @nodes_req = $xml_req->findnodes('/honeynet/template');
          my $template_name = $nodes_req[$#nodes_req]->textContent;
          my $bool_t = check_template($template_name);
          if($bool_t == 0){
             print "The required template [$template_name] does not exist.\n";
             exit 0;
          }
       }
    }
    if($mode eq "autoclone"){
       my $bool_autoclone = $xml_req->exists('/honeynet/clone_type');
       if($bool_autoclone == 0){
            print "mode [autoclone] requires [clone_type].\n";
            exit 0;
       }
       $bool_autoclone = $xml_req->exists('/honeynet/target_network');
       if($bool_autoclone == 0){
            print "mode [autoclone] requires [target_network] ip prefix.\n";
            exit 0;
       }
       $bool_autoclone = $xml_req->exists('/honeynet/deploy_way');
       if($bool_autoclone == 0){
            print "mode [autoclone] requires [deploy_way].\n";
            exit 0;
       }
       $bool_autoclone = $xml_req->exists('/honeynet/net');
       if($bool_autoclone == 0){
            print "mode [autoclone] requires [net] to deploy honeypots.\n";
            exit 0;
       } 
    }
    if($mode eq "listen"){
       my $bool_listen = $xml_req->exists('/honeynet/trigger');
       if($bool_listen == 0){
            print "mode [listen] requires [trigger].\n";
            exit 0;
       }
       $bool_listen = $xml_req->exists('/honeynet/net');
       if($bool_listen == 0){
            print "mode [listen] requires [net] to deploy honeypots.\n";
            exit 0;
       } 
    }
=cut
}

sub check_scenario{
    my $scenario_name = $_[0];
    my $bool = 0;
    my $dir = '../scenarios';
    #opendir(DIR, $dir) or die $!;
    #while (my $file = readdir(DIR)) {
        # A file test to check that it is a directory
	# Use -f to test for a file, -d to test for a dir, -e to test for existing
    #    next unless (-d "$dir/$file");
    #	print "$file\n";
    #}
    #closedir(DIR);
    if (-e "$dir/$scenario_name"){
        #print "The scenario exists, modify it.\n";
        $bool = 1;
    }
    else{
        #print "the scenario does not exist, can create it now.\n";
    }
    return $bool;
}

sub check_template{
    my $template_name = $_[0];
    my $bool = 0;
    my $dir = '../templates';
    if (-e "$dir/$template_name"){
        #print "The required template exists.\n";
        $bool = 1;
    }
    else{
        #print "[Warning]: The required template does not exist.\n";
    }
    return $bool;
}

sub create_scenario{
   my $scenario_name = $_[0];
   my $dir = "../scenarios";
   my $xml_doc = XML::LibXML::Document->new('1.0', 'utf-8');
   my $root_scenario = $xml_doc->createElement("honeynet");
   #$root->setAttribute('some-attr'=> 'some-value');
   my %tags = (
      name => "$scenario_name",
   );
   for my $name (keys %tags) {
      my $tag = $xml_doc->createElement($name);
      my $value = $tags{$name};
      $tag->appendTextNode($value);
      $root_scenario->appendChild($tag);
   }
   $xml_doc->setDocumentElement($root_scenario);
   $xml_doc->toFile("$dir/$scenario_name");
   print "the scenario is created now.\n";
}


1;
