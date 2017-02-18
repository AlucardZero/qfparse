#!/usr/bin/env perl
#  apt-get install mysql-server mysql-client unzip libxml-libxml-perl libconfig-simple-perl libdatetime-perl libdbd-mysql-perl
# mysql> create database qf;
# mysql> create table NPC (id INT PRIMARY KEY, Name VARCHAR(64));
# mysql> create table Quest (id INT PRIMARY KEY, Name VARCHAR(64), Zone VARCHAR(64), AddonId VARCHAR(32), NPCStart VARHCAR(32));

use Data::Dumper;
use XML::LibXML;
use XML::LibXML::Reader;
use Config::Simple;
use Scalar::Util qw/blessed/;
use POSIX qw/floor strftime/;
use DateTime;
use DBD::mysql;
use Time::HiRes qw/gettimeofday tv_interval/;
use Cwd qw/abs_path/;
use File::Basename;

my $t0 = [gettimeofday];

use strict;
use warnings;
binmode STDOUT, ":utf8";

my $CONFIGFILE = dirname(abs_path(__FILE__)) . "/qf.conf";
my $cfg = new Config::Simple($CONFIGFILE) or die "Failed to read $CONFIGFILE. $!\n";
my ($dsn, $dbh, $sth);

# Set up SQL connection
if ((defined $cfg->param('SQLDB')) && (defined $cfg->param('SQLLOC')) && (defined $cfg->param('SQLUSER')) && (defined $cfg->param('SQLPASS'))) {
	$dsn = "DBI:mysql:database=" . $cfg->param('SQLDB') . ";host=" . $cfg->param('SQLLOC') . ";";
	$dbh = DBI->connect($dsn, $cfg->param('SQLUSER'), $cfg->param('SQLPASS'), { mysql_enable_utf8 => 1, });
	if (!defined $dbh) {
		print STDERR "Error connecting to databse. " . $DBI::errstr . "\n";
	}
}
else { die "Insufficient SQL settings!\n"; }

my @files = qw/NPC Quest/;
my @namekeys = qw/PrimaryName Name/;
my @idkeys = qw/Id QuestId/;

#			q72272880 = {
#				QuestId = "1915168896",
#				AddonId = "q722728801C8AEFA9",
#				NPCStart = "Mecha Pilot Sergi",
#				ItemStart = "-24656234",
#				},
# I don't know what ItemStart is
while (my ($index, $file) = each @files) {
	my $reader = XML::LibXML::Reader->new(location => "${file}s.xml") or die $!;
	my $parser = XML::LibXML->new();
	while ( $reader->nextElement($file) ) {
		my $xml = $parser->parse_string($reader->readOuterXml());

		my $id = $xml->findnodes("/$file/$idkeys[$index]")->to_literal();
		my $name = $xml->findnodes("/$file/$namekeys[$index]/English")->to_literal();
		my $addonid = $xml->findnodes("/$file/AddonId")->to_literal();
		my $npcstart = $xml->findnodes("(/$file/Givers/NPCId)[1]")->to_literal();
		my $zone = $xml->findnodes("/$file/Zone")->to_literal();
		$name =~ s/^\s+|\s+$//g;
		my $success;
		if ($addonid) {
			$sth = $dbh->prepare("REPLACE INTO $file (Id, Name, Zone, AddonId, NPCStart) VALUES (?, ?, ?, ?, ?)");
			$success = $sth->execute($id, $name, $zone, $addonid, $npcstart);
		}
		else {
			$sth = $dbh->prepare("REPLACE INTO $file (Id, Name) VALUES (?, ?)");
			$success = $sth->execute($id, $name);
		}
		if (!$success) {
			print STDERR "$id, $name, $zone, $addonid, $npcstart\n";
			print STDERR "Error updating. " . $dbh->err . ": " . $DBI::errstr . "\n";
		}
	}
}
