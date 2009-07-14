package Support;
use strict;
use IO::File;
use File::Spec;
use Test::More;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(all_modules test_trace);

sub test_trace {
    my ($type, $file, $info) = @_;
    
    my $num_threads = $info->{'threads'};
    my $get_thread  = $info->{'thread'};
    my $num_frames  = $info->{'frames'};
    my $crash_frame_num = $info->{'crash_frame'};
    my $description = $info->{'description'};
    
    my $trace_file = new IO::File("t/traces/" . lc($type) . "/$file");
    my $trace_text;
    { local $/ = undef; $trace_text = <$trace_file>; }
    $trace_file->close();
    
    my $trace;
    my $class = "Parse::StackTrace::Type::$type";
    use_ok($class);
    isa_ok($trace = $class->parse(text => $trace_text, debug => $ENV{'PS_DEBUG'}),
           $class, $file);
    
    is(scalar @{ $trace->threads }, $num_threads,
       "trace has $num_threads threads");
    
    my $thread;
    is($thread = $trace->thread_number($get_thread),
       $trace->threads->[$get_thread - 1],
       "thread_number($get_thread) returns the right thread");
    
    ok(!$trace->thread_number($num_threads + 1),
       'there is no thread number ' . ($num_threads + 1));
    
    is(scalar @{ $thread->frames }, $num_frames,
       "thread has $num_frames frames");
    
    is($thread->description, $description,
       "thread description is: $description");
    
    is($thread->frame_number(0), $thread->frames->[0],
       'frame_number(0) returns first frame');
    
    ok(!$thread->frame_number($num_frames),
       "there is no frame number $num_frames");
    
    my $crash_frame;
    ok($crash_frame = $thread->frame_with_crash, 'thread has crash frame');
    is($crash_frame->number, $crash_frame_num,
       "crash frame is frame number $crash_frame_num");
}

# Stolen from Test::Pod::Coverage
sub all_modules {
    my @starters = @_ ? @_ : _starting_points();
    my %starters = map {$_,1} @starters;

    my @queue = @starters;

    my @modules;
    while ( @queue ) {
        my $file = shift @queue;
        if ( -d $file ) {
            local *DH;
            opendir DH, $file or next;
            my @newfiles = readdir DH;
            closedir DH;

            @newfiles = File::Spec->no_upwards( @newfiles );
            @newfiles = grep { $_ ne "CVS" && $_ ne ".svn" && $_ ne '.bzr' }
                             @newfiles;

            push @queue, map "$file/$_", @newfiles;
        }
        if ( -f $file ) {
            next unless $file =~ /\.pm$/;

            my @parts = File::Spec->splitdir( $file );
            shift @parts if @parts && exists $starters{$parts[0]};
            shift @parts if @parts && $parts[0] eq "lib";
            $parts[-1] =~ s/\.pm$// if @parts;

            # Untaint the parts
            for ( @parts ) {
                if ( /^([a-zA-Z0-9_\.\-]+)$/ && ($_ eq $1) ) {
                    $_ = $1;  # Untaint the original
                }
                else {
                    die qq{Invalid and untaintable filename "$file"!};
                }
            }
            my $module = join( "::", @parts );
            push( @modules, $module );
        }
    } # while

    return @modules;
}
