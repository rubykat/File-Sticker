package File::Sticker::Writer::Mp3;

=head1 NAME

File::Sticker::Writer::Mp3 - write and standardize meta-data from MP3 file

=head1 SYNOPSIS

    use File::Sticker::Writer::Mp3;

    my $obj = File::Sticker::Writer::Mp3->new(%args);

    my %meta = $obj->write_meta(%args);

=head1 DESCRIPTION

This will write meta-data from MP3 files, and standardize it to a common
nomenclature, such as "tags" for things called tags, or Keywords or Subject etc.

=cut

use common::sense;
use File::LibMagic;
use MP3::Tag;

use parent qw(File::Sticker::Writer);

# FOR DEBUGGING
sub whoami  { ( caller(1) )[3] }

=head1 METHODS

=head2 allowed_file

If this writer can be used for the given file, then this returns true.
File must be an MP3 file.

=cut

sub allowed_file {
    my $self = shift;
    my $file = shift;
    say STDERR whoami(), " file=$file" if $self->{verbose} > 2;

    my $ft = $self->{file_magic}->info_from_filename($file);
    if ($ft->{mime_type} eq 'audio/mpeg')
    {
        return 1;
    }
    return 0;
} # allowed_file

=head2 known_fields

Returns the fields which this writer knows about.

    my $known_fields = $writer->known_fields();

=cut

sub known_fields {
    my $self = shift;

    return {
        title=>'TEXT',
        description=>'TEXT',
        creator=>'TEXT',
        author=>'TEXT',
        genre=>'TEXT',
        song=>'TEXT',
        url=>'TEXT',
        tags=>'MULTI'};
} # known_fields

=head1 Helper Functions

=cut

=head2 replace_one_field

Overwrite the given field. This does no checking.

    $writer->replace_one_field(filename=>$filename,field=>$field,value=>$value);

=cut

sub replace_one_field {
    my $self = shift;
    my %args = @_;
    say STDERR whoami(), " filename=$args{filename}" if $self->{verbose} > 2;

    my $filename = $args{filename};
    my $field = $args{field};
    my $value = $args{value};

    my $mp3 = MP3::Tag->new($filename);
    $mp3->config(write_v24=>1);

    if ($field eq 'title')
    {
        $mp3->album_set($value);
    }
    elsif ($field eq 'song')
    {
        $mp3->title_set($value);
    }
    elsif ($field eq 'description')
    {
        $mp3->comment_set($value);
    }
    elsif ($field eq 'creator')
    {
        $mp3->artist_set($value);
    }
    elsif ($field eq 'genre')
    {
        $mp3->genre_set($value);
    }
    elsif ($field eq 'author')
    {
        # use the 'composer' field
        $mp3->select_id3v2_frame_by_descr('TCOM', $value);
    }
    elsif ($field eq 'url')
    {
        # official audio file webpage
        $mp3->select_id3v2_frame_by_descr('WOAF', $value);
    }
    elsif ($field eq 'tags')
    {
        my $newtags = $value;
        if (ref $value eq 'ARRAY')
        {
            $newtags = join(',', @{$value});
        }
        $mp3->select_id3v2_frame_by_descr('TXXX[tags]', $newtags);
    }
    $mp3->update_tags();
} # replace_one_field

=head2 delete_field_from_file

Remove the given field. This does no checking.
This doesn't completely remove it, merely sets it to the empty string.

    $writer->delete_field_from_file(filename=>$filename,field=>$field);

=cut

sub delete_field_from_file {
    my $self = shift;
    my %args = @_;
    say STDERR whoami(), " filename=$args{filename}" if $self->{verbose} > 2;

    my $filename = $args{filename};
    my $field = $args{field};

    my $mp3 = MP3::Tag->new($filename);
    $mp3->config(write_v24=>1);

    if ($field eq 'title')
    {
        $mp3->album_set('');
    }
    elsif ($field eq 'song')
    {
        $mp3->title_set('');
    }
    elsif ($field eq 'description')
    {
        $mp3->comment_set('');
    }
    elsif ($field eq 'creator')
    {
        $mp3->artist_set('');
    }
    elsif ($field eq 'author')
    {
        # use the 'composer' field
        $mp3->select_id3v2_frame_by_descr('TCOM', '');
    }
    elsif ($field eq 'url')
    {
        # official audio file webpage
        $mp3->select_id3v2_frame_by_descr('WOAF', '');
    }
    elsif ($field eq 'tags')
    {
        $mp3->select_id3v2_frame_by_descr('TXXX[tags]', '');
    }
    $mp3->update_tags();
} # delete_field_from_file

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of File::Sticker::Writer
__END__
