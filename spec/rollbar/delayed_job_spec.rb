require 'spec_helper'
require 'delayed_job'
require 'rollbar/delayed_job'
require 'delayed/backend/test'

describe Rollbar::Delayed, :reconfigure_notifier => true do
  class FailingJob
    class TestException < Exception; end

    def do_job_please!(a, b)
      this = will_crash_again!
    end
  end

  before(:all) do
    # technically, this is called once when rollbar hooks are required
    Rollbar::Delayed.wrap_worker!
  end

  before do
    Delayed::Backend::Test.prepare_worker

    Delayed::Worker.backend = :test
    Delayed::Backend::Test::Job.delete_all
  end

  let(:expected_args) do
    [kind_of(NoMethodError), { :use_exception_level_filters => true }]
  end

  context 'with delayed method without arguments failing' do
    it 'sends the exception' do
      expect(Rollbar).to receive(:scope).with(kind_of(Hash)).and_call_original
      expect_any_instance_of(Rollbar::Notifier).to receive(:error).with(*expected_args)

      FailingJob.new.delay.do_job_please!(:foo, :bar)
    end
  end


  describe '.build_job_data' do
    let(:job) { double(:payload_object => {}) }

    context 'if report_dj_data is disabled' do
      before do
        allow(Rollbar.configuration).to receive(:report_dj_data).and_return(false)
      end

      it 'returns nil' do
        expect(described_class.build_job_data(job)).to be_nil
      end
    end

    context 'with report_dj_data enabled' do
      before do
        allow(Rollbar.configuration).to receive(:report_dj_data).and_return(true)
      end

      it 'returns a hash' do
        result = described_class.build_job_data(job)
        expect(result).to be_kind_of(Hash)
      end
    end
  end

  describe '.skip_report' do
    let(:configuration) { Rollbar.configuration }
    let(:threshold) { 5 }

    before do
      allow(configuration).to receive(:dj_threshold).and_return(threshold)
    end

    context 'with attempts > configuration.dj_threshold' do
      let(:job) { double(:attempts => 6) }

      it 'returns true' do
        expect(described_class.skip_report?(job)).to be(false)
      end
    end

    context 'with attempts < configuration.dj_threshold' do
      let(:job) { double(:attempts => 3) }

      it 'returns false' do
        expect(described_class.skip_report?(job)).to be(true)
      end
    end
  end
end
