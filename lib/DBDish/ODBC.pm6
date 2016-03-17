use v6;
need DBDish;

unit class DBDish::ODBC:auth<salortiz>:ver<0.0.1> does DBDish::Driver;
use DBDish::ODBC::Native;
need DBDish::ODBC::Connection;

has SQLENV $!Env;

submethod BUILD(:$!Env!, :$!parent, :$!RaiseError) { };

method new(*%args) {
    with SQLENV.Alloc {
	self.bless(:Env($_), |%args);
    }
    else { .fail }
}

method !chkerr($rep) is hidden-from-backtrace {
    $rep ~~ ODBCErr ?? self!conn-error(:errstr($rep[1]), :code($rep[0])) !! $rep;
}

proto method connect(*%args) { * };
multi method connect(
    :$conn-str!, :$RaiseError = $!RaiseError, *%args
) {
    my $conn = SQLDBC.Alloc($!Env);
    with self!chkerr: $conn.Connect($conn-str, Str, Str, Str) {
	DBDish::ODBC::Connection.new(:$conn, :fconn-str($_), :$RaiseError,
	    :parent(self), |%args
	);
    }
    else { .fail }
}

multi method connect(
    :database(:$dsn)!, :$user = "", :$pass = "", :$RaiseError = $!RaiseError, *%args
) {
    my $conn = SQLDBC.Alloc($!Env);
    with self!chkerr: $conn.Connect(Str, $dsn, $user, $pass) {
	DBDish::ODBC::Connection.new(:$conn, :fconn-str($_), :$RaiseError,
	    :parent(self), |%args
	);
    }
    else { .fail }
}
