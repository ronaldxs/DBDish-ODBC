use v6;
need DBDish;

unit class DBDish::ODBC::StatementHandle does DBDish::StatementHandle;
use DBDish::ODBC::Native;
use NativeCall;

has SQLDBC $!conn is required;
has SQLSTMT $!sth is required;
has Str $!statement;
has @!param-type;
has $!field_count;

submethod BUILD(:$!conn!, :$!parent!,
    :$!sth!, :@!param-type, :$!statement = '', :$!RaiseError
) { }

method !handle-error($rep) {
    $rep ~~ ODBCErr ?? self!set-err(|$rep) !! $rep
}

method execute(*@params) {
    self!enter-execute(@params.elems, @!param-type.elems);

    my @bufs; # For preserve in scope our buffers till Execute
    my Buf[int64] $SoI .= allocate(+@params);
    for @params.kv -> $k, $v {
	if $v.defined {
	    my $param = ($v ~~ Blob) ?? $v !! (~$v).encode;
	    @bufs.push($param);
	    $SoI[$k] = $param.bytes;
	    self!handle-error($!sth.BindParameter($k+1, @!param-type[$k], $param, $SoI));
	} else {
	    $SoI[$k] = SQL_NULL_DATA;
	    self!handle-error($!sth.BindParameter($k+1, @!param-type[$k], Buf, $SoI));
	}
    }

    without self!handle-error: $!statement
	?? $!sth.ExecDirect($!statement)
	!! $!sth.handle-res($!sth.Execute) { .fail }

    my $rows = $!sth.RowCount; my $was-select = True;
    without $!field_count {
	$!field_count = $!sth.NumResultCols;
	for ^$!field_count {
	    my $meta = $!sth.DescribeCol($_+1);
	    @!column-name.push($meta<name>);
	    @!column-type.push($meta<type>);
	}
	# TODO, not all ODBC drivers returns a sensible RowCount for SELECT
    }
    unless $!field_count {
	$was-select = False;
    }
    self!done-execute($rows, $was-select);
}

method _row(:$hash) {
    my $list = ();
    if $!field_count -> $cols {
	given $!sth.Fetch {
	    when SQL_SUCCESS {
		$list = do for ^$cols {
		    my $type = @!column-type[$_]; my $raw = $type ~~ Buf;
		    my $value = do with $!sth.GetData($_ + 1, :$raw) {
			$raw ?? $_ !! .$type
		    } else { $type }
		}
	    }
	    when SQL_NO_DATA { self.finish }
	}
    }
    $list;
}

method _free {
    with $!sth {
	.dispose;
	$_ = Nil;
    }
}

method finish {
    with $!sth {
	.CloseCursor if $!field_count;
    }
    $!Finished = True;
}
