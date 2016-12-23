#!/usr/bin/perl -w
package configurationEngine;
use File::Copy;
use XML::LibXML;
use Config::Scoped;
use strict;
use warnings;
use common;
use vnx_module;
use honeyd_module;
require Exporter;
our(@EXPORT, @ISA, @EXPORT_OK);
@ISA=qw(Exporter);
@EXPORT=qw(create_scenario_from_template create_scenario_from_script generate_conf delete_scenario set_scenario);
@EXPORT_OK=qw();

sub create_scenario_from_template{
   my ($scenario_name, $template_name) = @_;
   my $dir_t = "../templates";
   my $dir_s = "../scenarios";
   my $scenario_doc = "$dir_s/$scenario_name";   
   copy("$dir_t/$template_name","$scenario_doc") or die "Create scenario from template failed: $!";
   my $parser = XML::LibXML->new();
   my $xml_scenario = $parser->parse_file($scenario_doc);
   my $root_scenario = $xml_scenario->getDocumentElement;
   my @nodes = $xml_scenario->findnodes('/honeynet/name');
   my $node=$nodes[$#nodes];
   $node->removeChildNodes();
   $node->appendText($scenario_name);
   $xml_scenario->toFile($scenario_doc);
   print "The scenario is created now.\n";
   return $scenario_doc;
}

sub create_scenario_from_script{
   my ($req_doc, $scenario_name) = @_;
   my $dir_s = "../scenarios";
   my $scenario_doc = "$dir_s/$scenario_name";   
   copy("$req_doc","$scenario_doc") or die "Create scenario from script failed: $!";
   my $parser = XML::LibXML->new();
   my $xml_scenario = $parser->parse_file("$scenario_doc");
   my $root_scenario = $xml_scenario->getDocumentElement;
   $root_scenario->removeAttribute( "request" );
   #$root_scenario->removeAttribute( "mode" );
   $xml_scenario->toFile("$scenario_doc");
   print "The scenario is created now.\n";
   return $scenario_doc;
}

sub generate_conf{
   my $scenario_doc = $_[0];
   my $cfg_hash = get_conf_hash($dir_conf);
   my $platform = $cfg_hash->{config}->{platform};
   if($platform eq "vnx"){      
        my $scenario_vnx_doc = generate_vnx_conf($scenario_doc);
        return $scenario_vnx_doc;
   }
   if($platform eq "honeyd"){
        my $scenario_honeyd_doc = generate_honeyd_conf($scenario_doc);
        print "$scenario_honeyd_doc\n";
        my($scenario_vnx_net, $net_name) = generate_vnx_net_for_honeyd($scenario_doc);
        return ($scenario_honeyd_doc,$scenario_vnx_net,$net_name);
   }
   if($platform eq "hybrid"){
   }
   if($platform eq "CIM"){    
   }     
}

sub delete_scenario{
   my ($scenario_name) = @_;
   my $cfg_hash = get_conf_hash($dir_conf);
   my $platform = $cfg_hash->{config}->{platform};
   my $scenario_doc = $dir_scenarios.$scenario_name;
   if($platform eq "vnx"){
         my $scenario_vnx_doc = $dir_scenarios.$scenario_name."_vnx.xml";
         print "go-------------$scenario_vnx_doc\n";
         system("vnx -f $scenario_vnx_doc -v -P -D");
         system("rm $scenario_doc*");
   }
   if($platform eq "honeyd"){
         my $scenario_honeyd_doc = $dir_scenarios.$scenario_name."_honeyd.txt";
         my $scenario_vnx_net = $dir_scenarios.$scenario_name."_vnx_net.xml";

         my $parser = XML::LibXML->new();
         my $xml_scenario = $parser->parse_file("$scenario_doc");
         my @nodes_scenario = $xml_scenario->getDocumentElement->nonBlankChildNodes();
         foreach my $node_scenario(@nodes_scenario){
            my $node_name = $node_scenario->nodeName;
            if($node_name eq "honeypot" ||$node_name eq "router"){
                  my @names = $node_scenario->findnodes('name');
                  my $name = $names[$#names]->textContent;
                  honeyd_del_template($name);
                  my @interfaces = $node_scenario->findnodes('if');
                  foreach my $interface (@interfaces){
                        my @ipv4s = $interface->findnodes('ipv4');
                        my $ipv4 = $ipv4s[$#ipv4s]->textContent;
                        honeyd_del_template($ipv4);
                  }
            } 
         }
         system ("vnx -f $scenario_vnx_net -v -P -D");
         system("rm $scenario_doc*");
         
   }
   if($platform eq "hybrid"){        
   }
   if($platform eq "CIM"){        
   }
          
}

sub set_scenario{
   my ($p_xml_req, $scenario_name) = @_;
   
   my $scenario_doc = $dir_scenarios.$scenario_name;
   my $parser = XML::LibXML->new();
   my $xml_scenario = $parser->parse_file($scenario_doc); 
   
   my @nodes_req = $$p_xml_req->getDocumentElement->nonBlankChildNodes();  
   foreach my $node_req(@nodes_req){
      my $node_name = $node_req->nodeName;
      if($node_name eq "net"){
          my $node_net = $node_req;
          my $net_status = "";
          my $bool_a = $node_net->hasAttribute('status');
          if($bool_a == 1){
             $net_status = $node_net->getAttribute('status');
          }
          my $net_request =""; 
          $bool_a = $node_net->hasAttribute('request');
          if($bool_a == 1){
             $net_request = $node_net->getAttribute('request');
          }
          my @node_net_names = $node_net->findnodes('name');
          my $node_net_name = $node_net_names[$#node_net_names]->textContent; 
          my @scenario_nets = $xml_scenario->findnodes('/honeynet/net');
          my $bool = 0;
          foreach my $scenario_net (@scenario_nets){
             my @scenario_net_names = $scenario_net->findnodes('name');
             my $scenario_net_name = $scenario_net_names[$#scenario_net_names]->textContent;
             if($scenario_net_name eq $node_net_name){
                $bool = 1;
                print "The net [$node_net_name] already exists in the scenario [$scenario_name]. It can be set and deleted, but can not be added.\n";      
                if($net_status ne ""){
                   $scenario_net->setAttribute('status', $net_status);      
                }      
                if($net_request eq "del"){
                   del_net(\$xml_scenario, $scenario_net, $scenario_name);
                }
                if($net_request eq "set"){
                   set_net(\$scenario_net, $node_net, $scenario_name);
                }
             }     
          }
          if($bool == 0){
             print "The net [$node_net_name] does not exist in the scenario [$scenario_name]. It can be be added.\n";
             if($net_request eq "add"){ 
                 my $clone_node_net =$node_net->cloneNode(1); 
                 add_net(\$xml_scenario, $clone_node_net, $scenario_name);
             }
          }     
      }
      if($node_name eq "router"){
      }
      if($node_name eq "honeypot"){
          my $node_honeypot = $node_req;
          my $honeypot_status = "";
          my $bool_a = $node_honeypot->hasAttribute('status');
          if($bool_a == 1){
             $honeypot_status = $node_honeypot->getAttribute('status');
          }
          my $honeypot_request =""; 
          $bool_a = $node_honeypot->hasAttribute('request');
          if($bool_a == 1){
             $honeypot_request = $node_honeypot->getAttribute('request');
          }          
          my @node_honeypot_names = $node_honeypot->findnodes('name');
          my $node_honeypot_name = $node_honeypot_names[$#node_honeypot_names]->textContent; 
          my @scenario_honeypots = $xml_scenario->findnodes('/honeynet/honeypot');
          my $bool = 0;
          foreach my $scenario_honeypot (@scenario_honeypots){
             my @scenario_honeypot_names = $scenario_honeypot->findnodes('name');
             my $scenario_honeypot_name = $scenario_honeypot_names[$#scenario_honeypot_names]->textContent;
             if($scenario_honeypot_name eq $node_honeypot_name){
                $bool = 1;
                print "The honeypot [$node_honeypot_name] already exists in the scenario [$scenario_name]. It can be set and deleted, but can not be added.\n";      
                if($honeypot_status ne ""){
                    $scenario_honeypot->setAttribute('status', $honeypot_status);      
                }
                if($honeypot_request eq "del"){
                    del_honeypot(\$xml_scenario, $scenario_honeypot, $scenario_name);
                }
                if($honeypot_request eq "set"){
                    set_honeypot(\$scenario_honeypot, $node_honeypot, $scenario_name);
                }
             }     
          }
          if($bool == 0){
             print "The honeypot [$node_honeypot_name] does not exist in the scenario [$scenario_name]. It can be be added.\n";
             if($honeypot_request eq "add"){ 
                 
                 my $clone_node_honeypot =$node_honeypot->cloneNode(1);
                 add_honeypot(\$xml_scenario, $clone_node_honeypot, $scenario_name);
             }
          }                           
      }
   }
   $xml_scenario->toFile($scenario_doc);
   indent_xml($scenario_doc);
  
   print "set scenario no2------------------------------\n";
   print "$$p_xml_req\n\n";
   my ($scenario_vnx_reconf,$scenario_honeyd_reconf)=generate_reconf($scenario_name,$p_xml_req);  
   return ($scenario_name,$scenario_vnx_reconf,$scenario_honeyd_reconf);                
}

sub del_net{
    my ($p_xml_scenario, $scenario_net, $scenario_name) = @_;
    my @scenario_net_names = $scenario_net->findnodes('name');
    my $scenario_net_name = $scenario_net_names[$#scenario_net_names]->textContent; 
    $$p_xml_scenario->getDocumentElement->removeChild($scenario_net);
    print "The net [$scenario_net_name] is eliminated now.\n";
    my @honeypot_ifs = $$p_xml_scenario->findnodes("/honeynet/honeypot/if[\@net='$scenario_net_name']");
    foreach my $honeypot_if(@honeypot_ifs){
        $honeypot_if->removeAttribute("net");       
    }           
}

sub set_net{
   my($p_scenario_net, $node_net, $scenario_name) = @_;
}

sub add_net{
   my ($p_xml_scenario, $node_net, $scenario_name) = @_;
   my @scenario_nets = $$p_xml_scenario->findnodes('/honeynet/net');
   $$p_xml_scenario->getDocumentElement()->insertAfter($node_net, $scenario_nets[$#scenario_nets]);
   my @node_net_names = $node_net->findnodes('name');
   my $node_net_name = $node_net_names[$#node_net_names]->textContent; 
   print "The net [$node_net_name] is succesfully added to scenario [$scenario_name]\n";
   
}

sub del_honeypot{
   my($p_xml_scenario, $scenario_honeypot, $scenario_name) = @_;
   my @scenario_honeypot_names = $scenario_honeypot->findnodes('name');
   my $scenario_honeypot_name = $scenario_honeypot_names[$#scenario_honeypot_names]->textContent; 
   $$p_xml_scenario->getDocumentElement->removeChild($scenario_honeypot);
   print "The honeypot [$scenario_honeypot_name] is eliminated now.\n";         
   #code: should delete the net if there is not any interface connects to it.
   my $bool = 0;
   my @honeypot_ifs = $scenario_honeypot->getChildrenByTagName('if');
   my $if_net;      
   foreach my $honeypot_if (@honeypot_ifs){
      $if_net = $honeypot_if->getAttribute('net');
      my @scenario_nets =  $$p_xml_scenario->findnodes('/honeynet/net');
      foreach my $scenario_net (@scenario_nets){
          my @scenario_net_names = $scenario_net->findnodes('name');
          my $scenario_net_name = $scenario_net_names[$#scenario_net_names]->textContent;
          if($scenario_net_name eq $if_net){
              my @scenario_honeypot_ifs = $$p_xml_scenario->findnodes("/honeynet/honeypot/if");
              foreach my $scenario_honeypot_if (@scenario_honeypot_ifs){
                  my $scenario_honeypot_if_net = $scenario_honeypot_if->getAttribute('net');
                  if($scenario_honeypot_if_net eq $scenario_net_name){
                     $bool = 1;
                  } 
              } 
          } 
      }
   }
   if($bool == 0){
       del_net_from_netlist($p_xml_scenario, $if_net);
   }   
}

sub del_net_from_netlist{
    my ($p_xml_scenario, $if_net) = @_;
    my @nets = $$p_xml_scenario->findnodes('/honeynet/net');
    foreach my $net (@nets){
        my @net_names = $net->findnodes('name');
        my $net_name = $net_names[$#net_names]->textContent;
        if ($net_name eq $if_net){
           $$p_xml_scenario->getDocumentElement->removeChild($net);
           print "The net [$net_name] is deleted from the Net list now.\n";
        } 
    }
}

sub add_honeypot{
  my($p_xml_scenario, $node_honeypot, $scenario_name) = @_; 
  #my $boolean = 1; 
  my @scenario_honeypots = $$p_xml_scenario->findnodes('/honeynet/honeypot');
  $$p_xml_scenario->getDocumentElement()->insertAfter($node_honeypot, $scenario_honeypots[$#scenario_honeypots]);
  my @node_honeypot_names = $node_honeypot->findnodes('name');
  my $node_honeypot_name = $node_honeypot_names[$#node_honeypot_names]->textContent; 
  print "The honeypot [$node_honeypot_name] is succesfully added to scenario [$scenario_name]\n";
  my @honeypot_ifs = $node_honeypot->getChildrenByTagName('if');      
  foreach my $honeypot_if (@honeypot_ifs){
      #append the IF of the new HP to the Net list if it isn't in the Net list 
      my $if_net = $honeypot_if->getAttribute('net');
      my @scenario_net_names =  $$p_xml_scenario->findnodes('/honeynet/net/name');
      my $bool = 0;
      foreach my $scenario_net_name (@scenario_net_names){
         my $name_txt = $scenario_net_name->textContent; 
         if($name_txt eq $if_net){
             $bool = 1;
             print "The net [$if_net] already exist in the Net list.\n";
         }
      }
      if($bool == 0){
           add_if_to_netlist($p_xml_scenario, $if_net);
      }
  } 
}

sub add_if_to_netlist{
    my ($p_xml_scenario, $if_net) = @_;
    my @nets = $$p_xml_scenario->findnodes('/honeynet/net');
    my $new_net =$nets[$#nets]->cloneNode(1);
    my @new_net_names = $new_net->findnodes('name'); 
    $new_net_names[0]->removeChildNodes();
    $new_net_names[0]->appendText($if_net);    
    $$p_xml_scenario->getDocumentElement()->insertAfter($new_net, $nets[$#nets]);
    print "The net [$if_net] is appended to the Net list now.\n";
}

sub set_honeypot{
   my($p_scenario_honeypot, $node_honeypot, $scenario_name) = @_;
   my @nodes_set = $node_honeypot->nonBlankChildNodes();
   foreach my $node_set (@nodes_set){
       my $node_set_name = $node_set->nodeName;
       if($node_set_name eq "if"){
           my $node_if = $node_set;
           operate_if($p_scenario_honeypot, $node_if);
       }
       if($node_set_name eq "operating_system"){
       }
       if($node_set_name eq "service"){
           my $node_service = $node_set;
           operate_service($p_scenario_honeypot, $node_service);
       }
       if($node_set_name eq "software"){
       }
  }
}

sub operate_if{
  my ($p_scenario_honeypot, $node_if) = @_;
  
  my $if_status ="";
  my $bool_a = $node_if->hasAttribute('status');
  if($bool_a == 1){
       $if_status = $node_if->getAttribute('status');
  }
  my $if_request =""; 
  $bool_a = $node_if->hasAttribute('request');
  if($bool_a == 1){
       $if_request = $node_if->getAttribute('request');
  }

  my $if_net = $node_if->getAttribute('net');  
  my $boolean = $$p_scenario_honeypot->exists("if[\@net='$if_net']");
  if ($boolean == 0){
     print "The interface [$if_net] does not exist in the honeypot. It can not be set and deleted. It can be added.\n";
     if($if_request eq 'add'){
     }     
  }
  if($boolean == 1){
     print "The interface [$if_net] exists in the honeypot. It can be set and deleted.\n";
     my @scenario_honeypot_ifs = $$p_scenario_honeypot->findnodes("if[\@net='$if_net']");
     my $scenario_honeypot_if = $scenario_honeypot_ifs[$#scenario_honeypot_ifs]; 
     if($if_status ne ""){
        $scenario_honeypot_if->setAttribute('status', $if_status);      
     }
     if($if_request eq 'set'){
        set_if(\$scenario_honeypot_if, $node_if); 
     }
     
     if($if_request eq 'del'){  
     }
  }  
}

sub set_if{
  my ($p_scenario_honeypot_if, $node_if) = @_;
  #reconf ip address
  my @if_children = $node_if->nonBlankChildNodes();
  foreach my $if_child (@if_children){
     my $if_child_name = $if_child->nodeName;
     if ($if_child_name eq "ipv4"){
        my $bool = $$p_scenario_honeypot_if->exists("ipv4");
        if($bool == 0){
            $$p_scenario_honeypot_if->addChild($if_child);
        }
        else{
            my @scenario_honeypot_if_ipv4s = $$p_scenario_honeypot_if->findnodes("ipv4");
            $$p_scenario_honeypot_if->removeChild($scenario_honeypot_if_ipv4s[0]);
            $$p_scenario_honeypot_if->addChild($if_child);
        }
     }
  }       
}

sub operate_serivce{
  my ($p_scenario_honeypot, $node_service) = @_;
  my $service_request = $node_service->getAttribute('request');
  my $service_status = $node_service->getAttribute('status');

  my $service_status ="";
  my $bool_a = $node_service->hasAttribute('status');
  if($bool_a == 1){
       $service_status = $node_service->getAttribute('status');
  }
  my $service_request =""; 
  $bool_a = $node_service->hasAttribute('request');
  if($bool_a == 1){
       $service_request = $node_service->getAttribute('request');
  }


  my @node_service_names = $node_service->findnodes('name');
  my $node_service_name = $node_service_names[$#node_service_names];
  my @scenario_honeypot_services = $$p_scenario_honeypot->findnodes("serivce");
  my $bool = 0;
  foreach my $scenario_honeypot_service (@scenario_honeypot_services){
     my @scenario_honeypot_service_names = $scenario_honeypot_service->findnodes("name");
     foreach my $scenario_honeypot_service_name (@scenario_honeypot_service_names){
        if($scenario_honeypot_service_name eq $node_service_name){
           $bool = 1;
           if($service_status ne ""){
              $scenario_honeypot_service->setAttribute('status', $service_status);      
           }
           if($service_request eq 'set'){
              set_service(\$scenario_honeypot_service, $node_service); 
           }
           if($service_request eq 'del'){
              del_service($p_scenario_honeypot,$scenario_honeypot_service);  
           }
        } 
     } 
  }  
  if ($bool == 0){
     if($service_request eq 'add'){
         add_service($p_scenario_honeypot, $node_service);
     }
     else{
        print "ERROR: This service $node_service_name does not exist in the scenario\n";
        exit 0;
     }
  }    
}

sub set_service{
  my ($p_scenario_honeypot_service, $node_service) = @_;
  my @service_children = $node_service->nonBlankChildNodes();
  foreach my $service_child (@service_children){
     my $service_child_name = $service_child->nodeName;
     if ($service_child_name eq "name"){
        my $bool = $$p_scenario_honeypot_service->exists("name");
        if($bool == 0){
            $$p_scenario_honeypot_service->addChild($service_child);
        }
        else{
            my @scenario_honeypot_service_names = $$p_scenario_honeypot_service->findnodes("name");
            $$p_scenario_honeypot_service->removeChild($scenario_honeypot_service_names[0]);
            $$p_scenario_honeypot_service->addChild($service_child);
        }
     }
     if ($service_child_name eq "port"){
        my $bool = $$p_scenario_honeypot_service->exists("port");
        if($bool == 0){
            $$p_scenario_honeypot_service->addChild($service_child);
        }
        else{
            my @scenario_honeypot_service_ports = $$p_scenario_honeypot_service->findnodes("port");
            $$p_scenario_honeypot_service->removeChild($scenario_honeypot_service_ports[0]);
            $$p_scenario_honeypot_service->addChild($service_child);
        }
     }
  }
}

sub del_service{
    my($p_scenario_honeypot,$scenario_honeypot_service) = @_;
    $$p_scenario_honeypot->removeChild($scenario_honeypot_service);
}
sub add_service{
    my($p_scenario_honeypot, $node_service) = @_;
    $$p_scenario_honeypot->appendChild($node_service);
}

sub generate_reconf{
   my($scenario_name,$p_xml_req) = @_;
   
   my $cfg_hash = get_conf_hash($dir_conf);
   my $platform = $cfg_hash->{config}->{platform};
   my $scenario_vnx_reconf;
   my $scenario_honeyd_reconf;
   if($platform eq "vnx"){
         $scenario_vnx_reconf = generate_vnx_reconf($scenario_name,$p_xml_req);
   }
   if($platform eq "honeyd"){
         $scenario_honeyd_reconf = generate_honeyd_reconf($scenario_name,$p_xml_req);
   }
   if($platform eq "hybrid"){
         ($scenario_vnx_reconf,$scenario_honeyd_reconf) = generate_hybrid_reconfs($scenario_name,$p_xml_req);
   }
   if($platform eq "CIM"){    
   }
   return ($scenario_vnx_reconf,$scenario_honeyd_reconf);
}

sub generate_hybrid_reconf{
   my ($scenario_name,$xml_req) = @_;
   my $scenario_vnx_reconf;
   my $scenario_honeyd_reconf;
   #code
   return ($scenario_vnx_reconf,$scenario_honeyd_reconf);
}

=pod
#Net
sub down_net{
  my($doc, $down_net, $scename) = @_; 
  my $net_name = $down_net->getAttribute('name');
  #ifconfig $net_name down
  #TBC
  print "ifconfig $net_name down.\n";
  
}

sub up_net{
  my($doc, $up_net, $scename) = @_;
  my $net_name = $up_net->getAttribute('name');
  #ifconfig $net_name up
  #TBC
  print "ifconfig $net_name up.\n";
}

sub modify_add_net{
  my($doc, $add_net, $scename) = @_;
  my $net_name = $add_net->getAttribute('name');
  my $boolean = $doc->exists("/vnx/net[\@name='$net_name']");
  if($boolean == 1){
      print "ERROR: cannot add net $net_name to scenario $scename (a net $net_name
already exists)\n";
  }
  else{
      #Add new Net
      #TBC

      # Add net to specification
      $add_net->setNodeName('net');
      my @nets = $doc->findnodes('/vnx/net');
      $doc->getDocumentElement()->insertAfter($add_net, $nets[$#nets]);
      print "$net_name succesfully added to scenario $scename\n";
  }
}

sub modify_del_net{
   my($doc, $del_net, $scename) = @_;
   my $net_name = $del_net->getAttribute('name');
   my $boolean = $doc->exists("/vnx/net[\@name='$net_name']");
   if($boolean == 0){
      print "ERROR: cannot add net $net_name to scenario $scename (a net $net_name
doesn't exist)\n";
   }
   else{
      #Del Net
      my $del = $del_net->getAttribute('del');
      if($del eq "no"){
         my $bool = $doc->exists("/vnx/vm/if[\@net='$net_name']");
         my $bool_hostif = $doc->exists("/vnx/host/hostif[\@net='$net_name']");
         if($bool == 1 || $bool_hostif == 1 ){
            print "ERROR: cannot del net $net_name in scenario $scename (a VM is still connected to $net_name)\n";
         }
         else{
            my @nets = $doc->findnodes("/vnx/net[\@name='$net_name']");
            $doc->getDocumentElement->removeChild($nets[0]);
            print "The net $net_name is deleted successfully.\n";     
         }
      }
      if($del eq "if"){
         my $bool = $doc->exists("/vnx/vm/if[\@net='$net_name']");
         if($bool == 1){
            my @ifs = $doc->findnodes("/vnx/vm/if[\@net='$net_name']");
            foreach my $if (@ifs){
                my $if_parent = $if->parentNode;
                my $parent_name = $if_parent->getAttribute('name');
                my $if_id = $if->getAttribute('id'); 
                $if_parent->removeChild($if);
                print "IF id=$if_id that connects to $net_name in vm $parent_name is eliminated.\n";
            }     
         }
         my $bool_hostif = $doc->exists("/vnx/host/hostif[\@net='$net_name']");
         if ($bool_hostif == 1){
            my @hosts = $doc->findnodes("/vnx/host");
            my @hostifs = $doc->findnodes("/vnx/host/hostif[\@net='$net_name']");
            $hosts[0]->removeChild($hostifs[0]);
            print "The hostif connected to the net $net_name is eliminated\n";
         } 
         my @nets = $doc->findnodes("/vnx/net[\@name='$net_name']");
         $doc->getDocumentElement->removeChild($nets[0]);
         print "The net $net_name is deleted successfully.\n";
      }
      if($del eq "vm"){
         my $bool = $doc->exists("/vnx/vm/if[\@net='$net_name']");
         if($bool == 1){
            my @ifs = $doc->findnodes("/vnx/vm/if[\@net='$net_name']");
            foreach my $if (@ifs){
                my $if_parent = $if->parentNode;
                my $parent_name = $if_parent->getAttribute('name');
                my $if_id = $if->getAttribute('id'); 
                $doc->getDocumentElement->removeChild($if_parent);
                print "vm $parent_name that has IF id=$if_id connects to $net_name is eliminated.\n";
            }     
         }
         my $bool_hostif = $doc->exists("/vnx/host/hostif[\@net='$net_name']");
         if ($bool_hostif == 1){
            my @hosts = $doc->findnodes("/vnx/host");
            $doc->getDocumentElement->removeChild($hosts[0]);
            print "host connected the net $net_name is eliminated\n";
         } 
         my @nets = $doc->findnodes("/vnx/net[\@name='$net_name']");
         $doc->getDocumentElement->removeChild($nets[0]);
         print "The net $net_name is deleted successfully.\n";
      }
  }
}

#IF
sub add_if_to_netlist{
    my ($doc, $if_net) = @_;
    my @nets = $doc->findnodes('/vnx/net');
    my $new_net =$nets[$#nets]->cloneNode(1);
    $new_net->setAttribute('name', $if_net);
    $doc->getDocumentElement()->insertAfter($new_net, $nets[$#nets]);
    print "$if_net is appended to the Net list now.\n";
}


sub vm_add_if{
   my ($doc, $modify_vm, $add_if, $scename) = @_;
   my $if_id = $add_if->getAttribute('id');
   my $if_net = $add_if->getAttribute('net');
   my $vm_name = $modify_vm->getAttribute('name');
   #To check if the new IF exists in VM IFs
   my $bool = $doc->exists("/vnx/vm[\@name='$vm_name']/if[\@id='$if_id']");
   if($bool == 1 ){
      print "  IF id=$if_id already exist in $vm_name\'s IF list.\n";
   }
   else{
      my @vms = $doc->findnodes("/vnx/vm[\@name='$vm_name']");
      my @ifs=$doc->findnodes("/vnx/vm[\@name='$vm_name']/if");
      $add_if->setNodeName('if');
      $vms[0]->insertAfter($add_if, $ifs[$#ifs]);   
      print "  IF id=$if_id is appended to $vm_name\'s IF list now.\n";
      #check the VM IF exist in the Net list
      my $bool = $doc->exists("/vnx/net[\@name='$if_net']");
      if($bool ==1 ){
         print "  $if_net already exist in the Net list.\n";
      }
      else{
         add_if_to_netlist($doc, $if_net);  
      }                 
   }
}

sub vm_modify_if{
   my ($doc, $modify_vm, $modify_if, $scename) = @_;
   my $if_id = $modify_if->getAttribute('id');
   my $if_net = $modify_if->getAttribute('net');
   my $vm_name = $modify_vm->getAttribute('name');
   #To check if the new IF exists in VM IFs
   my $bool = $doc->exists("/vnx/vm[\@name='$vm_name']/if[\@id='$if_id']");
   if($bool == 0 ){
      print "  IF id=$if_id doesn't exist in $vm_name\'s IF list.\n";
   }
   else{
      #To check if the IF's net value is the same with the net value in the modi_xml
      my @vm_ifs = $doc->findnodes("/vnx/vm[\@name='$vm_name']/if[\@id='$if_id']");
      my $vm_if_net = $vm_ifs[0]->getAttribute('net');
      if($vm_if_net eq $if_net){
         print "the IF id=$if_id has the net $if_net, thus don't need to change the net value.\n"
      }
      else{
         $vm_ifs[0]->setAttribute('net', $if_net);
         #To check if the new net value exist in the net list 
         my $bool = $doc->exists("/vnx/net[\@name='$if_net']");
         if($bool == 1){
            print "  $if_net already exist in the Net list.\n";
         }
         else{
            add_if_to_netlist($doc, $if_net);
         }
      }
      #To modify the IP of the IF in the target VM node
      my @ipv4s = $modify_if->getChildrenByTagName('ipv4');
      my $ipAddr = $ipv4s[0]->textContent;
      my @vm_if_ips = $doc->findnodes("/vnx/vm[\@name='$vm_name']/if[\@id='$if_id']/ipv4");
      $vm_if_ips[0]->removeChildNodes();
      $vm_if_ips[0]->appendText($ipAddr);
      print "  The IP address of $if_id in $vm_name is switched to $ipAddr\n ";
   }
}

sub vm_del_if{
   my ($doc, $modify_vm, $del_if, $scename) = @_;
   my $if_id = $del_if->getAttribute('id');
   my $vm_name = $modify_vm->getAttribute('name');
   #To check if the IF exists in VM IFs
   my $bool = $doc->exists("/vnx/vm[\@name='$vm_name']/if[\@id='$if_id']");
   if($bool == 0 ){
      print "  IF id=$if_id doesn't exist in $vm_name\'s IF list.\n";
   }
   else{
      my @vms = $doc->findnodes("/vnx/vm[\@name='$vm_name']");
      my @vm_ifs = $doc->findnodes("/vnx/vm[\@name='$vm_name']/if[\@id='$if_id']");
      $vms[0]->removeChild($vm_ifs[0]);
      print "  The IF id=$if_id in $vm_name is removed now.\n";
   }
}


#VM
sub modify_vm_element{
  my($doc, $modify_vm, $scename) = @_;
  my $vm_name = $modify_vm->getAttribute('name');
  my $boolean = $doc->exists("/vnx/vm[\@name='$vm_name']");
  #To check if the VM exist
  if($boolean == 0){
     print "ERROR: cannot modify $vm_name in scenario $scename (the vm $vm_name
doesn't exist)\n";
  }
  else{       
     my @operations = $modify_vm->nonBlankChildNodes();
     foreach my $operation (@operations){
        my $opName = $operation->nodeName;
        if($opName eq "add_if"){
           print "  <$opName>:\n";
           vm_add_if($doc, $modify_vm, $operation, $scename);
           print "\n";
        }
        if($opName eq "modify_if"){
           print "  <$opName>:\n";
           vm_modify_if($doc, $modify_vm, $operation, $scename);
           print "\n";
        }
        if($opName eq "del_if"){
           print "  <$opName>:\n";
           vm_del_if($doc, $modify_vm, $operation, $scename);
           print "\n";
        } 
     }
  }
}

sub modify_add_vm{
  my($doc, $add_vm, $scename) = @_;
  my @vms = $doc->findnodes('/vnx/vm');  
  #insert the vm if it isn't existed
  my $vm_name = $add_vm->getAttribute('name');
  my $boolean = $doc->exists("/vnx/vm[\@name='$vm_name']");
  if($boolean == 1){
     print "ERROR: cannot add net $vm_name to scenario $scename (a vm $vm_name
already exists)\n";
  }
  else{
     $add_vm->setNodeName('vm');
     $doc->getDocumentElement()->insertAfter($add_vm, $vms[$#vms]);
     print "$vm_name succesfully added to scenario $scename\n";
     my @vm_ifs = $add_vm->getChildrenByTagName('if');      
     foreach my $vm_if (@vm_ifs){
        #append the IF in the new VM to the Net list if it isn't in the Net list 
        my $if_net = $vm_if->getAttribute('net');
        my $bool = $doc->exists("/vnx/net[\@name='$if_net']");
        if($bool == 1){
           print "$if_net already exist in the Net list.\n";
        }
        else{
           add_if_to_netlist($doc, $if_net);
        }
     }
  }     
}


sub modify_del_vm{
   my($doc, $del_vm, $scename) = @_;
   my $vm_name = $del_vm->getAttribute('name');
   my $bool = $doc->exists("/vnx/vm[\@name='$vm_name']");
   if($bool == 1){
      my @del_vms = $doc->findnodes("/vnx/vm[\@name='$vm_name']");
      $doc->getDocumentElement->removeChild($del_vms[0]);
      print "$vm_name is eliminated now.\n";
   }
   else{
      print "$vm_name isn't found.\n";
   }
}

sub modify_vm_attributes{
   my($doc, $modify_vm, $scename) = @_;
   my $vm_name = $modify_vm->getAttribute('name');
   my $bool = $doc->exists("/vnx/vm[\@name='$vm_name']");
   if($bool == 1){
       my @attributes = $modify_vm->nonBlankChildNodes();
       foreach my $attribute (@attributes){
           my $attr_name = $attribute->nodeName;
           if($attr_name eq "name"){
              my $attr_value = $attribute->textContent;
              my $boolean = $doc->exists("/vnx/vm[\@name='$attr_value']");
              #To check if this name already was already occupied.
              if($boolean==1){
                 print "This vm name $attr_value was already occupied by other vm.\n";
              }
              else{  
                my @modify_vms = $doc->findnodes("/vnx/vm[\@name='$vm_name']");
                #It is dangerous to change the value of attribute 'name' of a VM
                $modify_vms[0]->setAttribute('name', $attr_value);
                print "The name of node $vm_name is changed to $attr_value\n";
              } 
           }
           #add other operations here
       }
   }
   else{
      print "$vm_name isn't found.\n";
   }
}

#get the parameters
my @confs = getConfs(@ARGV);
my $origConf = $confs[0];
my $modiConf = $confs[1];
#initial
my $parser = XML::LibXML->new();
my $docVNX = $parser->parse_file($origConf);
my $docModi = $parser->parse_file($modiConf);
#my $nodeVNX = $docVNX->getDocumentElement;
#my $nodeModi = $docModi->getDocumentElement;
my $scename = "SCENARIO";
#operation
my @operations = $docModi->getDocumentElement->nonBlankChildNodes();
foreach my $operation (@operations){
   my $opName = $operation->nodeName;
   if($opName eq "add_net"){
       print "<$opName>:\n";
       modify_add_net($docVNX, $operation, $scename);
       print "\n";
   }
   if($opName eq "add_vm"){
       print "<$opName>:\n";
       modify_add_vm($docVNX, $operation, $scename);
       print "\n";
   }
   if($opName eq "vm"){
       my $vmName = $operation->getAttribute('name');
       print "<$opName $vmName>:\n";
       modify_vm_element($docVNX, $operation, $scename);
       print "\n";
   }
   if($opName eq "del_vm"){
       print "<$opName>:\n";
       modify_del_vm($docVNX, $operation, $scename);
       print "\n";
   }
   if($opName eq "modify_vm"){
       print "<$opName>:\n";
       modify_vm_attributes($docVNX, $operation, $scename);
       print "\n";
   }
   if($opName eq "del_net"){
       print "<$opName>:\n";
       modify_del_net($docVNX, $operation, $scename);
       print "\n";
   }
   if($opName eq "down_net"){
       print "<$opName>:\n";
       down_net($docVNX, $operation, $scename);
       print "\n";
   }
   if($opName eq "up_net"){
       print "<$opName>:\n";
       up_net($docVNX, $operation, $scename);
       print "\n";
   }
   #add other operations here
}
$docVNX->toFile($origConf);
print "\n";
=cut
1;
