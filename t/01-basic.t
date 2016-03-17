use v6;
use Test;
use DBIish;

plan 13;

my $drv;
lives-ok {
    $drv = DBIish.install-driver('ODBC');
}, 'Can install driver';

throws-like {
    $drv.connect(:database<NoSush>);
}, X::DBDish::ConnectionFailed,
   :code<IM002>, # The ODBC error code expected
   :message(/ '[Driver Manager]' /), # The level of the error
   'Bogus connect';

ok my $dbh = $drv.connect(:conn-str('Driver=PostgreSQL;database=dbdishtest;uid=postgres')),
   'Can connect with a connection string';

isa-ok $dbh, ::('DBDish::ODBC::Connection');

ok $dbh.fconn-str, 'Full connection string available';

ok (my @res = $dbh.execute(q|SELECT 'Hola a todos', 5|)), 'Can execute statement';
is @res, ['Hola a todos', 5], 'The right values';

ok (my $sth = $dbh.prepare(q|SELECT 'Hola a todos'|)), 'Can prepare statement';

isa-ok $sth, ::('DBDish::ODBC::StatementHandle');

is $dbh.Statements.elems, 1, 'One statement';

ok $sth.dispose, 'Can dispose the statement';

is $dbh.Statements.elems,  0,  'Zero statemens';

ok $dbh.dispose, 'Can dispose the connection';
diag "Continuará";
