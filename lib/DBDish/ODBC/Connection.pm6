use v6;
need DBDish;

unit class DBDish::ODBC::Connection does DBDish::Connection;
need DBDish::ODBC::StatementHandle;
use DBDish::ODBC::Native;

has SQLDBC $!conn;
has Str $.fconn-str;

submethod BUILD(:$!conn!, :$!fconn-str!, :$!parent!, :$!RaiseError) { };

method !handle-error($rep) {
    $rep ~~ ODBCErr ?? self!set-err(|$rep) !! $rep
}

method prepare(Str $statement, *%args) {
    with SQLSTMT.Alloc($!conn) -> $sth {
	self!handle-error: $sth.Prepare($statement);
	my @param-type;
	with self!handle-error($sth.NumParams) -> $params {
	    for ^$params {
		with self!handle-error: $sth.DescribeParam($_+1) {
		    @param-type.push: $_;
		} else { .fail }
	    }
	}
	else { .fail }
	DBDish::ODBC::StatementHandle.new(
	    :$sth, :$!conn, :parent(self), :param-type(@param-type), :$.RaiseError
	)
    } else { .fail }
}

method execute(Str $statement) {
    my $sth = SQLSTMT.Alloc($!conn);
    without self!handle-error: $sth.ExecDirect($statement) { .fail }
    my @results;
    if $sth.NumResultCols -> $cols {
	loop (my $rc = $sth.Fetch; $rc == SQL_SUCCESS; $rc = $sth.Fetch) {
	    for ^$cols {
		with $sth.GetData($_+1) -> $data {
		    @results[$_] = val($data);
		}
	    }
	}
    }
    @results;
}

method ping {
    True; # TODO
}

method _disconnect {
    with $!conn {
	.Disconnect;
	.dispose;
	$_ = Nil;
    }
}
