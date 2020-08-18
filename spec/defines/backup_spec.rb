require 'spec_helper'

describe 'restic::backup' do
  let(:title) { 'namevar' }
  let(:params) do
    {
      'files' => '/var/backups',
      'repo'  => 's3:s3.amazonaws.com/bucket_backups',
    }
  end
  let(:pre_condition) { 'include restic' }

  on_supported_os.each do |os, os_facts|
    context "on #{os}" do
      let(:facts) { os_facts }

      it { is_expected.to compile }
    end
  end
end
