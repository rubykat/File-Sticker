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

=head1 METHODS

=head2 allowed_file

If this writer can be used for the given file, then this returns true.
File must be an MP3 file.

=cut

sub allowed_file {
    my $self = shift;
    my $file = shift;

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
        url=>1,
        creator=>1,
        author=>1,
        title=>1,
        description=>1,
        tags=>1};
} # known_fields

=head2 write_meta

Write the meta-data to the given file.

    $obj->write_meta(filename=>$filename, meta=>\%meta);

=cut

sub write_meta {
    my $self = shift;
    my %args = @_;

} # write_meta

=head1 Helper Functions

=cut

=head2 add_tag_to_mp3

This will only set freeform tags.

$writer->add_tag_to_mp3($filename,$tag);

=cut
sub add_tag_to_mp3 ($$$) {
    my $self = shift;
    my $fullname = shift;
    my $tag = shift;

    my $mp3 = MP3::Tag->new($fullname);
    $mp3->config(write_v24=>1);

    # add a new tag to existing tags
    my %th = ();
    $th{$tag} = 1;

    if ($mp3->have_id3v2_frame('TXXX', [qw(tags)]))
    {
        my $tagframe = $mp3->select_id3v2_frame('TXXX', [qw(tags)], undef);
        my @oldtags = split(/,/, $tagframe);
        foreach my $t (@oldtags)
        {
            $th{$t} = 1;
        }
    }
    my @newtags = keys %th;
    @newtags = sort @newtags;
    my $newtags = join(',', @newtags);
    $mp3->select_id3v2_frame_by_descr('TXXX[tags]', $newtags);

    $mp3->update_tags();
} # add_tag_to_mp3

=head1 BUGS

Please report any bugs or feature requests to the author.

=cut

1; # End of File::Sticker::Writer
__END__
