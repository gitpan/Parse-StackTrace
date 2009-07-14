use inc::Module::Install;

name 'Parse-StackTrace';
all_from 'lib/Parse/StackTrace.pm';

requires 'Scalar::Util';
requires 'Exception::Class';
requires 'Moose';
requires 'MooseX::AttributeHelpers';

test_requires 'Test::More';
test_requires 'File::Spec';

WriteAll;